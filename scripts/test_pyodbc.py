"""Temporary, read-only diagnostic for direct pyodbc SQL Server connections."""

import traceback
import sys

import pyodbc


SERVER = "localhost,1433"
DATABASE = "AdventureWorks2022"


def main() -> None:
    print(f"pyodbc.version: {pyodbc.version}")
    installed_drivers = pyodbc.drivers()
    print(f"pyodbc.drivers(): {installed_drivers}")

    sql_server_drivers = [
        driver
        for driver in installed_drivers
        if "SQL Server" in driver
    ]

    if not sql_server_drivers:
        print("No Microsoft ODBC Drivers for SQL Server were found.")
        return

    for driver in sql_server_drivers:
        print(f"\nTrying {driver}...", flush=True)
        connection_string = (
            f"DRIVER={{{driver}}};"
            f"SERVER={SERVER};"
            f"DATABASE={DATABASE};"
            "Trusted_Connection=yes;"
            "Encrypt=no;"
            "TrustServerCertificate=yes;"
        )

        try:
            with pyodbc.connect(connection_string, timeout=5) as connection:
                cursor = connection.cursor()
                cursor.execute("SELECT DB_NAME()")
                print(f"Connected database: {cursor.fetchone()[0]}")
        except Exception:
            traceback.print_exc(file=sys.stdout)


if __name__ == "__main__":
    main()
