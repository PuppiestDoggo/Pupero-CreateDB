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

echo ">>> Initializing schema for database: $DB_NAME"

"$CLIENT" -uroot -p"$ROOT_PW" <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE \`$DB_NAME\`;

SET FOREIGN_KEY_CHECKS=0;

-- Users table
CREATE TABLE IF NOT EXISTS \`user\` (
  id INT NOT NULL AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL,
  username VARCHAR(50) NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'user',
  totp_secret VARCHAR(32) NULL,
  phrase VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_disabled TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_email (email),
  UNIQUE KEY uq_user_username (username),
  KEY ix_user_email (email),
  KEY ix_user_username (username)
) ENGINE=InnoDB;

-- Offers table
CREATE TABLE IF NOT EXISTS \`offer\` (
  id INT NOT NULL AUTO_INCREMENT,
  public_id CHAR(36) NOT NULL,
  title VARCHAR(255) NOT NULL,
  \`desc\` VARCHAR(2048) NOT NULL,
  price_xmr DECIMAL(18,8) NOT NULL,
  seller_id INT NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'open',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_offer_public_id (public_id),
  KEY ix_offer_public_id (public_id),
  KEY ix_offer_title (title),
  KEY ix_offer_seller_id (seller_id),
  KEY ix_offer_status (status),
  KEY ix_offer_timestamp (timestamp)
) ENGINE=InnoDB;

-- Transactions table
CREATE TABLE IF NOT EXISTS \`transaction\` (
  id INT NOT NULL AUTO_INCREMENT,
  offer_id INT NOT NULL,
  buyer_id INT NOT NULL,
  seller_id INT NOT NULL,
  amount DECIMAL(18,8) NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'pending',
  tx_hash VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_transaction_tx_hash (tx_hash),
  KEY ix_transaction_offer_id (offer_id),
  KEY ix_transaction_buyer_id (buyer_id),
  KEY ix_transaction_seller_id (seller_id),
  KEY ix_transaction_status (status),
  KEY ix_transaction_created_at (created_at)
) ENGINE=InnoDB;

-- UserBalance table
CREATE TABLE IF NOT EXISTS \`userbalance\` (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  fake_xmr DECIMAL(18,8) NOT NULL DEFAULT 0.0,
  real_xmr DECIMAL(18,8) NOT NULL DEFAULT 0.0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_balance_user_id (user_id),
  KEY ix_userbalance_user_id (user_id),
  KEY ix_userbalance_updated_at (updated_at)
) ENGINE=InnoDB;

-- LedgerTx table
CREATE TABLE IF NOT EXISTS \`ledgertx\` (
  id INT NOT NULL AUTO_INCREMENT,
  from_user_id INT NOT NULL,
  to_user_id INT NOT NULL,
  amount_xmr DECIMAL(18,8) NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'completed',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_ledgertx_from_user_id (from_user_id),
  KEY ix_ledgertx_to_user_id (to_user_id),
  KEY ix_ledgertx_status (status),
  KEY ix_ledgertx_created_at (created_at)
) ENGINE=InnoDB;

-- Add foreign keys safely (skip if already exists)
ALTER TABLE \`offer\`
  ADD CONSTRAINT fk_offer_seller
  FOREIGN KEY (seller_id) REFERENCES \`user\`(id)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE \`transaction\`
  ADD CONSTRAINT fk_tx_offer
  FOREIGN KEY (offer_id) REFERENCES \`offer\`(id)
  ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_tx_buyer
  FOREIGN KEY (buyer_id) REFERENCES \`user\`(id),
  ADD CONSTRAINT fk_tx_seller
  FOREIGN KEY (seller_id) REFERENCES \`user\`(id);

ALTER TABLE \`userbalance\`
  ADD CONSTRAINT fk_balance_user
  FOREIGN KEY (user_id) REFERENCES \`user\`(id)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE \`ledgertx\`
  ADD CONSTRAINT fk_ledger_from_user
  FOREIGN KEY (from_user_id) REFERENCES \`user\`(id),
  ADD CONSTRAINT fk_ledger_to_user
  FOREIGN KEY (to_user_id) REFERENCES \`user\`(id);

SET FOREIGN_KEY_CHECKS=1;
EOF

echo ">>> Schema initialization complete."
