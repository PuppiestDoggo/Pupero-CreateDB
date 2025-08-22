import argparse
import sys
import os
from typing import Optional


def build_database_url(driver: str, user: str, password: str, host: str, port: int, database: str) -> str:
    return f"{driver}://{user}:{password}@{host}:{port}/{database}"


def main():
    parser = argparse.ArgumentParser(description="Create database schema for Pupero Auth (SQLModel)")
    parser.add_argument("--user", required=True, help="DB username")
    parser.add_argument("--password", required=True, help="DB password")
    parser.add_argument("--host", default="127.0.0.1", help="DB host (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=3306, help="DB port (default: 3306)")
    parser.add_argument("--database", required=True, help="Database name to create tables in")
    parser.add_argument("--driver", default="mariadb+mariadbconnector", help="SQLAlchemy driver URL prefix (default: mariadb+mariadbconnector)")
    parser.add_argument("--echo", action="store_true", help="Enable SQL echo for debugging")
    parser.add_argument("--create-database", action="store_true", help="Create the database if it does not exist (uses utf8mb4)")

    args = parser.parse_args()

    # Build DATABASE_URL
    database_url = build_database_url(args.driver, args.user, args.password, args.host, args.port, args.database)

    # Ensure the Login package is importable (project root on sys.path)
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if project_root not in sys.path:
        sys.path.insert(0, project_root)

    # Import SQLModel and models from Login app
    try:
        from sqlmodel import SQLModel, create_engine
        from sqlalchemy import text
        from Login.app.models import User  # noqa: F401 - ensure model is registered with metadata
    except Exception as e:
        print(f"Failed to import dependencies or models: {e}")
        sys.exit(1)

    try:
        # Optionally create the database first by connecting to the server-level 'mysql' database
        if args.create_database:
            admin_db = "mysql"
            admin_url = build_database_url(args.driver, args.user, args.password, args.host, args.port, admin_db)
            admin_engine = create_engine(admin_url, echo=args.echo)
            with admin_engine.connect() as conn:
                conn.execute(text(
                    f"CREATE DATABASE IF NOT EXISTS `{args.database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                ))
                conn.commit()
            print(f"Database '{args.database}' ensured (created if missing).")

        engine = create_engine(database_url, echo=args.echo)
        SQLModel.metadata.create_all(engine)
        print("Database tables created successfully.")
    except Exception as e:
        print(f"Failed to create database tables: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
