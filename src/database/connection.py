"""SQL Server connection helpers for the local AdventureWorks database.

Settings are read from the project-root ``.env`` file. SQL Server
Authentication is used; credentials are never printed.
"""

from pathlib import Path
import os

from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, text
from sqlalchemy.engine import Engine


PROJECT_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(PROJECT_ROOT / ".env")


def create_database_engine() -> Engine:
    """Create an engine using SQL Server Authentication.

    Required environment variables: ``DB_SERVER``, ``DB_NAME``, ``DB_DRIVER``,
    ``DB_USER``, and ``DB_PASSWORD``. The engine connects lazily when first used.
    """
    required_settings = (
        "DB_SERVER",
        "DB_NAME",
        "DB_DRIVER",
        "DB_USER",
        "DB_PASSWORD",
    )
    settings = {name: os.getenv(name) for name in required_settings}
    missing = [name for name, value in settings.items() if not value]
    if missing:
        raise ValueError(
            "Missing required database settings: " + ", ".join(missing)
        )

    connection_url = URL.create(
        "mssql+pyodbc",
        username=settings["DB_USER"],
        password=settings["DB_PASSWORD"],
        host=settings["DB_SERVER"],
        database=settings["DB_NAME"],
        query={
            "driver": settings["DB_DRIVER"],
            "Encrypt": "no",
            "TrustServerCertificate": "yes",
        },
    )
    return create_engine(connection_url)


def test_connection() -> tuple[str, int]:
    """Run the two requested read-only checks and report their results."""
    engine = create_database_engine()
    try:
        with engine.connect() as connection:
            database_name = connection.execute(
                text("SELECT DB_NAME()")
            ).scalar_one()
        print(f"Connected to database: {database_name}")

        with engine.connect() as connection:
            result = connection.execute(
                text("SELECT TOP 5 * FROM Sales.Customer")
            )
            rows = result.fetchall()
        print(f"Sales.Customer query succeeded; rows returned: {len(rows)}")
        return database_name, len(rows)
    finally:
        engine.dispose()


if __name__ == "__main__":
    test_connection()
