#!/usr/bin/env bash
set -euo pipefail

: "${MYSQL_USERNAME:?MYSQL_USERNAME required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD required}"
: "${MYSQL_LOCAL_PORT:?MYSQL_LOCAL_PORT required}"
: "${MYSQL_HOST:?MYSQL_HOST required}"
: "${EXPECTED_MYSQL_HOST:?EXPECTED_MYSQL_HOST required}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE required}"
: "${ONBOARDING_ROLLBACK_FILE:?ONBOARDING_ROLLBACK_FILE required}"

[[ "$MYSQL_HOST" == "$EXPECTED_MYSQL_HOST" ]] || {
  echo '::error::Unexpected MySQL endpoint during onboarding rollback'
  exit 1
}
[[ "$MYSQL_DATABASE" == needu ]] || {
  echo '::error::Unexpected database during onboarding rollback'
  exit 1
}
[[ -s "$ONBOARDING_ROLLBACK_FILE" ]] || {
  echo '::error::Onboarding rollback snapshot is missing or empty'
  exit 1
}

python3 - <<'PY'
import json
import os
import sys

import pymysql


with open(os.environ["ONBOARDING_ROLLBACK_FILE"], encoding="utf-8") as snapshot_file:
    users = json.load(snapshot_file)
if not isinstance(users, list) or not users:
    raise RuntimeError("Invalid or empty onboarding rollback snapshot")

connection = pymysql.connect(
    host="127.0.0.1",
    port=int(os.environ["MYSQL_LOCAL_PORT"]),
    user=os.environ["MYSQL_USERNAME"],
    password=os.environ["MYSQL_PASSWORD"],
    database=os.environ["MYSQL_DATABASE"],
    charset="utf8mb4",
    autocommit=False,
    connect_timeout=10,
    read_timeout=30,
    write_timeout=30,
)

try:
    with connection.cursor() as cursor:
        cursor.execute("SELECT DATABASE(), @@hostname, @@read_only")
        database, hostname, read_only = cursor.fetchone()
        if database != "needu" or read_only:
            raise RuntimeError("Connected to the wrong or read-only MySQL database")
        cursor.execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
        cursor.execute("START TRANSACTION")

        for user in users:
            cursor.execute(
                """
                UPDATE users
                SET status = %s,
                    onboarding_completed = %s,
                    taste_analysis_completed = %s
                WHERE id = %s
                  AND (external_id IS NULL OR external_id >= 0)
                """,
                (
                    user["status"],
                    user["onboarding_completed"],
                    user["taste_analysis_completed"],
                    user["id"],
                ),
            )
            cursor.execute(
                """
                SELECT status, onboarding_completed, taste_analysis_completed
                FROM users
                WHERE id = %s AND (external_id IS NULL OR external_id >= 0)
                """,
                (user["id"],),
            )
            restored = cursor.fetchone()
            expected = (
                user["status"],
                user["onboarding_completed"],
                user["taste_analysis_completed"],
            )
            if restored != expected:
                raise RuntimeError(f"Could not restore prior state for user id={user['id']}")

        connection.commit()
        print(f"Restored pre-cutover onboarding state for {len(users)} non-test users")
except Exception as exc:
    try:
        connection.rollback()
    finally:
        print(f"::error::Onboarding rollback failed; transaction rolled back: {exc}", file=sys.stderr)
    sys.exit(1)
finally:
    connection.close()
PY
