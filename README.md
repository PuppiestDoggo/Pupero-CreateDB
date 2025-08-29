# DB

This directory builds the MariaDB server image (pupero-createdb) with schema initialization scripts. No Python package is exposed here and no other project should import from it.

## Purpose
- Provides MariaDB server container with init scripts under /docker-entrypoint-initdb.d
- Initializes the database and all tables on first startup (empty volume)

## How it works
- The official mariadb image runs any .sql/.sh placed in /docker-entrypoint-initdb.d on first run.
- Our init script (DB/initdb.d/01-schema.sh) creates the database and tables.

## Usage (Docker Compose)
- docker compose up will build and start the createdb service and initialize schema automatically.

## Manual build
```
docker build -t pupero-createdb -f DB/Dockerfile .
```

## Notes
- Services define their own models/schemas locally and connect to the DB via environment variables.
- No service imports code from this DB project.
