# CreateDB

CreateDB centralizes ALL database schema (SQLModel tables) and shared Pydantic schemas for the Pupero system. No other project defines database tables.

## Purpose
- Owns SQLModel models: User, Offer, Transaction, UserBalance, LedgerTx
- Owns Pydantic schemas used by services (auth, offers, transactions)
- Provides a small CLI to create the schema in MariaDB

## Requirements
- MariaDB server accessible via `DATABASE_URL` (or the CLI params)
- Python dependencies in `CreateDB/requirements.txt`

## Create database tables
You can create the database and tables either locally with Python or with Docker.

### Local usage
```
cd CreateDB
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Create tables (with server already created DB)
python main.py --user root --password mypass --host 127.0.0.1 --port 3306 --database pupero_auth --driver mariadb+mariadbconnector

# Optionally create the database if missing
python main.py --user root --password mypass --host 127.0.0.1 --port 3306 --database pupero_auth --driver mariadb+mariadbconnector --create-database
```

### Docker usage
```
docker build -t pupero-createdb -f CreateDB/Dockerfile .
# Create the DB (if missing) and tables by running the container with CLI args
docker run --rm pupero-createdb --user root --password mypass --host 127.0.0.1 --port 3306 --database pupero_auth --driver mariadb+mariadbconnector --create-database
```

## Notes
- All other services import models/schemas from `CreateDB` (e.g. `from CreateDB.models import User`)
- Services should NOT call `SQLModel.metadata.create_all`; schema management lives here.
