#!/bin/sh
set -e

DB_NAME="${MYSQL_DATABASE:-pupero_auth}"
ROOT_PW="${MYSQL_ROOT_PASSWORD}"

# Pick available client (mariadb or mysql)
CLIENT="$(command -v mariadb || command -v mysql || true)"
if [ -z "$CLIENT" ]; then
  echo "ERROR: neither 'mariadb' nor 'mysql' client found in PATH" >&2
  exit 1
fi

echo ">>> Initializing moderation schema for database: $DB_NAME"

"$CLIENT" -uroot -p"$ROOT_PW" <<EOF
USE \`$DB_NAME\`;

-- Report table (user reports)
CREATE TABLE IF NOT EXISTS \`report\` (
  id INT NOT NULL AUTO_INCREMENT,
  reporter_user_id INT NOT NULL,
  reported_user_id INT NULL,
  content_type VARCHAR(50) NOT NULL,
  content_id VARCHAR(255) NULL,
  category VARCHAR(50) NOT NULL,
  description TEXT NOT NULL,
  evidence TEXT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  assigned_moderator_id INT NULL,
  resolution_notes TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY ix_report_reporter_user_id (reporter_user_id),
  KEY ix_report_reported_user_id (reported_user_id),
  KEY ix_report_content_type (content_type),
  KEY ix_report_content_id (content_id),
  KEY ix_report_category (category),
  KEY ix_report_status (status),
  KEY ix_report_assigned_moderator_id (assigned_moderator_id),
  KEY ix_report_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Moderation Action table
CREATE TABLE IF NOT EXISTS \`moderation_action\` (
  id INT NOT NULL AUTO_INCREMENT,
  moderator_user_id INT NOT NULL,
  target_user_id INT NULL,
  action_type VARCHAR(50) NOT NULL,
  content_type VARCHAR(50) NULL,
  content_id VARCHAR(255) NULL,
  reason TEXT NOT NULL,
  details TEXT NULL,
  related_report_id INT NULL,
  related_dispute_id INT NULL,
  duration_minutes INT NULL,
  expires_at DATETIME NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  reversed_by_action_id INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_moderation_action_moderator_user_id (moderator_user_id),
  KEY ix_moderation_action_target_user_id (target_user_id),
  KEY ix_moderation_action_action_type (action_type),
  KEY ix_moderation_action_related_report_id (related_report_id),
  KEY ix_moderation_action_related_dispute_id (related_dispute_id),
  KEY ix_moderation_action_expires_at (expires_at),
  KEY ix_moderation_action_is_active (is_active),
  KEY ix_moderation_action_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User Moderation Status table
CREATE TABLE IF NOT EXISTS \`user_moderation_status\` (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  is_banned BOOLEAN NOT NULL DEFAULT FALSE,
  is_muted BOOLEAN NOT NULL DEFAULT FALSE,
  is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
  funds_frozen BOOLEAN NOT NULL DEFAULT FALSE,
  frozen_amount DOUBLE NOT NULL DEFAULT 0.0,
  warning_count INT NOT NULL DEFAULT 0,
  ban_reason TEXT NULL,
  mute_reason TEXT NULL,
  suspend_reason TEXT NULL,
  mute_expires_at DATETIME NULL,
  suspend_expires_at DATETIME NULL,
  last_action_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_moderation_status_user_id (user_id),
  KEY ix_user_moderation_status_user_id (user_id),
  KEY ix_user_moderation_status_is_banned (is_banned),
  KEY ix_user_moderation_status_is_muted (is_muted),
  KEY ix_user_moderation_status_is_suspended (is_suspended),
  KEY ix_user_moderation_status_funds_frozen (funds_frozen),
  KEY ix_user_moderation_status_mute_expires_at (mute_expires_at),
  KEY ix_user_moderation_status_suspend_expires_at (suspend_expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dispute table (trade disputes)
CREATE TABLE IF NOT EXISTS \`dispute\` (
  id INT NOT NULL AUTO_INCREMENT,
  transaction_id INT NOT NULL,
  offer_id INT NOT NULL,
  buyer_id INT NOT NULL,
  seller_id INT NOT NULL,
  initiated_by_user_id INT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'open',
  category VARCHAR(50) NOT NULL,
  description TEXT NOT NULL,
  buyer_statement TEXT NULL,
  seller_statement TEXT NULL,
  evidence_buyer TEXT NULL,
  evidence_seller TEXT NULL,
  assigned_moderator_id INT NULL,
  resolution_notes TEXT NULL,
  resolution_amount_to_buyer DOUBLE NULL,
  resolution_amount_to_seller DOUBLE NULL,
  funds_frozen_amount DOUBLE NOT NULL DEFAULT 0.0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY ix_dispute_transaction_id (transaction_id),
  KEY ix_dispute_offer_id (offer_id),
  KEY ix_dispute_buyer_id (buyer_id),
  KEY ix_dispute_seller_id (seller_id),
  KEY ix_dispute_initiated_by_user_id (initiated_by_user_id),
  KEY ix_dispute_status (status),
  KEY ix_dispute_category (category),
  KEY ix_dispute_assigned_moderator_id (assigned_moderator_id),
  KEY ix_dispute_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dispute Message table
CREATE TABLE IF NOT EXISTS \`dispute_message\` (
  id INT NOT NULL AUTO_INCREMENT,
  dispute_id INT NOT NULL,
  sender_user_id INT NOT NULL,
  is_moderator BOOLEAN NOT NULL DEFAULT FALSE,
  message TEXT NOT NULL,
  attachments TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_dispute_message_dispute_id (dispute_id),
  KEY ix_dispute_message_sender_user_id (sender_user_id),
  KEY ix_dispute_message_created_at (created_at),
  CONSTRAINT fk_dispute_message_dispute FOREIGN KEY (dispute_id) REFERENCES \`dispute\`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Appeal table
CREATE TABLE IF NOT EXISTS \`appeal\` (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  moderation_action_id INT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  reason TEXT NOT NULL,
  evidence TEXT NULL,
  assigned_moderator_id INT NULL,
  resolution_notes TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY ix_appeal_user_id (user_id),
  KEY ix_appeal_moderation_action_id (moderation_action_id),
  KEY ix_appeal_status (status),
  KEY ix_appeal_assigned_moderator_id (assigned_moderator_id),
  KEY ix_appeal_created_at (created_at),
  CONSTRAINT fk_appeal_moderation_action FOREIGN KEY (moderation_action_id) REFERENCES \`moderation_action\`(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit Log table
CREATE TABLE IF NOT EXISTS \`audit_log\` (
  id INT NOT NULL AUTO_INCREMENT,
  actor_user_id INT NOT NULL,
  actor_role VARCHAR(50) NOT NULL,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(50) NOT NULL,
  target_id VARCHAR(255) NULL,
  details TEXT NOT NULL,
  ip_address VARCHAR(45) NULL,
  user_agent VARCHAR(512) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_audit_log_actor_user_id (actor_user_id),
  KEY ix_audit_log_actor_role (actor_role),
  KEY ix_audit_log_action (action),
  KEY ix_audit_log_target_type (target_type),
  KEY ix_audit_log_target_id (target_id),
  KEY ix_audit_log_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Notification table
CREATE TABLE IF NOT EXISTS \`notification\` (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  notification_type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  channel VARCHAR(20) NOT NULL DEFAULT 'both',
  related_action_id INT NULL,
  related_report_id INT NULL,
  related_dispute_id INT NULL,
  related_appeal_id INT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  sent_in_app BOOLEAN NOT NULL DEFAULT FALSE,
  sent_matrix BOOLEAN NOT NULL DEFAULT FALSE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  read_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY ix_notification_user_id (user_id),
  KEY ix_notification_notification_type (notification_type),
  KEY ix_notification_is_read (is_read),
  KEY ix_notification_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Moderation Queue table
CREATE TABLE IF NOT EXISTS \`moderation_queue\` (
  id INT NOT NULL AUTO_INCREMENT,
  item_type VARCHAR(50) NOT NULL,
  item_id INT NOT NULL,
  priority INT NOT NULL DEFAULT 0,
  assigned_moderator_id INT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  claimed_at DATETIME NULL,
  completed_at DATETIME NULL,
  PRIMARY KEY (id),
  KEY ix_moderation_queue_item_type (item_type),
  KEY ix_moderation_queue_item_id (item_id),
  KEY ix_moderation_queue_priority (priority),
  KEY ix_moderation_queue_assigned_moderator_id (assigned_moderator_id),
  KEY ix_moderation_queue_status (status),
  KEY ix_moderation_queue_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Moderation Stats table (daily statistics)
CREATE TABLE IF NOT EXISTS \`moderation_stats\` (
  id INT NOT NULL AUTO_INCREMENT,
  date DATE NOT NULL,
  total_reports INT NOT NULL DEFAULT 0,
  resolved_reports INT NOT NULL DEFAULT 0,
  total_disputes INT NOT NULL DEFAULT 0,
  resolved_disputes INT NOT NULL DEFAULT 0,
  total_appeals INT NOT NULL DEFAULT 0,
  approved_appeals INT NOT NULL DEFAULT 0,
  denied_appeals INT NOT NULL DEFAULT 0,
  warnings_issued INT NOT NULL DEFAULT 0,
  mutes_issued INT NOT NULL DEFAULT 0,
  bans_issued INT NOT NULL DEFAULT 0,
  suspensions_issued INT NOT NULL DEFAULT 0,
  content_removed INT NOT NULL DEFAULT 0,
  funds_frozen_total DOUBLE NOT NULL DEFAULT 0.0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_moderation_stats_date (date),
  KEY ix_moderation_stats_date (date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add is_disabled and force_logout_at columns to user table if they don't exist
ALTER TABLE \`user\` ADD COLUMN IF NOT EXISTS is_disabled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE \`user\` ADD COLUMN IF NOT EXISTS force_logout_at DATETIME NULL;
ALTER TABLE \`user\` ADD COLUMN IF NOT EXISTS matrix_localpart VARCHAR(255) NULL;
ALTER TABLE \`user\` ADD COLUMN IF NOT EXISTS successful_trades INT NOT NULL DEFAULT 0;

-- Add indexes for new columns if they don't exist
-- Note: MariaDB doesn't support IF NOT EXISTS for indexes, so we use a workaround
-- These will fail silently if indexes already exist

EOF

echo ">>> Moderation schema initialization complete."
