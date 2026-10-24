# tests/conftest.py — shared psycopg 3 connection for the test suite.
# Reads the same variables the lab scripts use (.env is NOT auto-loaded:
# export them first or use `uv run pytest` inside the repo after sourcing).

import os

import pytest
import psycopg

REQUIRED_VARS = ("POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_USER", "POSTGRES_DB", "POSTGRES_PASSWORD")


@pytest.fixture(scope="session")
def conn():
    missing = [v for v in REQUIRED_VARS if not os.environ.get(v)]
    if missing:
        pytest.fail(f"Missing env vars: {', '.join(missing)} — source .env first "
                    f"(see .env.example).")
    conninfo = (f"host={os.environ['POSTGRES_HOST']} port={os.environ['POSTGRES_PORT']} "
                f"user={os.environ['POSTGRES_USER']} dbname={os.environ['POSTGRES_DB']} "
                f"password={os.environ['POSTGRES_PASSWORD']}")
    with psycopg.connect(conninfo) as connection:
        yield connection
