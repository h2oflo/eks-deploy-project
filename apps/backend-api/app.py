import os
from datetime import datetime, timezone

import boto3
import psycopg
from fastapi import FastAPI

app = FastAPI()

DB_HOST = os.environ["DB_HOST"]
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USER = os.environ.get("DB_USER", "dbadmin")
DB_PASSWORD = os.environ.get("DB_PASSWORD")  # local testing only
DB_SECRET_ARN = os.environ.get("DB_SECRET_ARN")  # RDS-managed master secret


def db_password() -> str:
    """Password from Secrets Manager (RDS-managed master secret) unless
    DB_PASSWORD was provided directly."""
    if DB_PASSWORD:
        return DB_PASSWORD
    client = boto3.client("secretsmanager")
    secret = client.get_secret_value(SecretId=DB_SECRET_ARN)
    import json

    return json.loads(secret["SecretString"])["password"]


def check_db() -> bool:
    try:
        with psycopg.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=db_password(),
            connect_timeout=5,
        ) as conn:
            conn.execute("SELECT 1")
        return True
    except Exception:
        return False


@app.get("/")
def status():
    return {
        "pod_name": os.environ.get("HOSTNAME", "unknown"),
        "db_status": "connected" if check_db() else "error",
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
