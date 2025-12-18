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
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_email (email),
  UNIQUE KEY uq_user_username (username),
  KEY ix_user_email (email),
  KEY ix_user_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Offers table
CREATE TABLE IF NOT EXISTS \`offer\` (
  id INT NOT NULL AUTO_INCREMENT,
  public_id CHAR(36) NOT NULL,
  title VARCHAR(255) NOT NULL,
  \`desc\` VARCHAR(2048) NOT NULL,
  price_xmr DOUBLE NOT NULL,
  seller_id INT NOT NULL DEFAULT 0,
  status VARCHAR(32) NOT NULL DEFAULT 'open',
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_offer_public_id (public_id),
  KEY ix_offer_public_id (public_id),
  KEY ix_offer_title (title),
  KEY ix_offer_seller_id (seller_id),
  KEY ix_offer_status (status),
  KEY ix_offer_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Transactions table (reserved name, keep quoted)
CREATE TABLE IF NOT EXISTS \`transaction\` (
  id INT NOT NULL AUTO_INCREMENT,
  offer_id INT NOT NULL,
  buyer_id INT NOT NULL DEFAULT 0,
  seller_id INT NOT NULL DEFAULT 0,
  amount DOUBLE NOT NULL,
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- UserBalance table
CREATE TABLE IF NOT EXISTS \`userbalance\` (
  id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  fake_xmr DOUBLE NOT NULL DEFAULT 0.0,
  real_xmr DOUBLE NOT NULL DEFAULT 0.0,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_balance_user_id (user_id),
  KEY ix_userbalance_user_id (user_id),
  KEY ix_userbalance_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- LedgerTx table
CREATE TABLE IF NOT EXISTS \`ledgertx\` (
  id INT NOT NULL AUTO_INCREMENT,
  from_user_id INT NOT NULL,
  to_user_id INT NOT NULL,
  amount_xmr DOUBLE NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'completed',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY ix_ledgertx_from_user_id (from_user_id),
  KEY ix_ledgertx_to_user_id (to_user_id),
  KEY ix_ledgertx_status (status),
  KEY ix_ledgertx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
EOF

echo ">>> Schema initialization complete."
