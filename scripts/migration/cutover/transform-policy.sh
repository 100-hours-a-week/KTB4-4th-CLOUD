#!/usr/bin/env bash
set -euo pipefail

: "${MYSQL_USERNAME:?}" "${MYSQL_PASSWORD:?}" "${MYSQL_LOCAL_PORT:?}" "${MYSQL_HOST:?}" "${EXPECTED_MYSQL_HOST:?}" "${MYSQL_DATABASE:=needu}"
[[ "$MYSQL_HOST" == "$EXPECTED_MYSQL_HOST" ]] || { echo '::error::Unexpected MySQL endpoint'; exit 1; }
[[ "$MYSQL_DATABASE" == needu ]] || { echo '::error::Unexpected database'; exit 1; }
[[ "${POLICY_TEST_USER_MIN:-}" == 59 && "${POLICY_TEST_USER_MAX:-}" == 78 ]] || { echo '::error::Test user range not explicitly confirmed'; exit 1; }
[[ "${CUTOVER_POLICY_APPROVED:-}" == YES ]] || { echo '::error::Policy transform approval missing'; exit 1; }

python3 - <<'PY'
import os
import sys
import pymysql

connection = pymysql.connect(
    host='127.0.0.1', port=int(os.environ['MYSQL_LOCAL_PORT']),
    user=os.environ['MYSQL_USERNAME'], password=os.environ['MYSQL_PASSWORD'],
    database=os.environ['MYSQL_DATABASE'], charset='utf8mb4',
    autocommit=False, connect_timeout=10, read_timeout=30, write_timeout=30,
)

def count(cursor, query):
    cursor.execute(query)
    return int(cursor.fetchone()[0])

try:
    with connection.cursor() as cur:
        cur.execute('SELECT DATABASE(), @@hostname, @@read_only')
        db_name, server_name, read_only = cur.fetchone()
        if db_name != 'needu' or read_only:
            raise RuntimeError('Wrong or read-only MySQL database')
        print(f'Connected database={db_name}, server={server_name}', flush=True)
        cur.execute('SET TRANSACTION ISOLATION LEVEL READ COMMITTED')
        cur.execute('START TRANSACTION')
        cur.execute("""
            UPDATE users SET
                status = CASE WHEN status = 'ACTIVE' THEN 'ONBOARDING' ELSE status END,
                onboarding_completed = 0, taste_analysis_completed = 0
            WHERE id NOT BETWEEN 59 AND 78
        """)
        cur.execute("""
            UPDATE users SET status = 'ACTIVE', onboarding_completed = 1,
                taste_analysis_completed = 1 WHERE id BETWEEN 59 AND 78
        """)
        for table in ('user_taste_profiles', 'personal_recommendations',
                      'gift_recommendations', 'ai_messages'):
            cur.execute(f'DELETE FROM `{table}`')
        cur.execute("""
            UPDATE ai_chat_rooms SET status = 'EXPIRED', active_user_id = NULL,
                updated_at = UTC_TIMESTAMP(6)
            WHERE status IN ('PENDING','ACTIVE','ANALYZING')
        """)
        checks = {
            'invalid_general_users': """
                SELECT COUNT(*) FROM users WHERE id NOT BETWEEN 59 AND 78
                AND (status = 'ACTIVE' OR NOT (onboarding_completed <=> 0)
                     OR NOT (taste_analysis_completed <=> 0))
            """,
            'invalid_test_users': """
                SELECT COUNT(*) FROM users WHERE id BETWEEN 59 AND 78
                AND (NOT (status <=> 'ACTIVE') OR NOT (onboarding_completed <=> 1)
                     OR NOT (taste_analysis_completed <=> 1))
            """,
            'in_progress_rooms': """
                SELECT COUNT(*) FROM ai_chat_rooms
                WHERE status IN ('PENDING','ACTIVE','ANALYZING')
            """,
            'invalid_categories': """
                SELECT COUNT(*) FROM products
                WHERE category IS NOT NULL AND category COLLATE utf8mb4_bin NOT IN
                ('VOUCHER','LIVING','BEAUTY','FASHION','FOOD','DIGITAL',
                 'HEALTH','LUXURY','BOOKS_TICKETS','SPORTS','PET')
            """,
        }
        for table in ('ai_messages','user_taste_profiles',
                      'personal_recommendations','gift_recommendations'):
            checks[f'nonempty_{table}'] = f'SELECT COUNT(*) FROM `{table}`'
        failures = {}
        for name, query in checks.items():
            value = count(cur, query)
            print(f'{name}={value}', flush=True)
            if value != 0:
                failures[name] = value
        if failures:
            raise RuntimeError(f'Policy validation failed: {failures}')
        connection.commit()
        print('POLICY_TRANSFORM_COMMITTED', flush=True)
except Exception as exc:
    try:
        connection.rollback()
    finally:
        print(f'::error::Policy transform failed, rollback attempted: {exc}', file=sys.stderr)
    sys.exit(1)
finally:
    connection.close()
PY
