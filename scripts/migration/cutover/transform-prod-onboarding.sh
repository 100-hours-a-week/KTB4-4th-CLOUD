#!/usr/bin/env bash
set -euo pipefail

: "${MYSQL_USERNAME:?MYSQL_USERNAME required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD required}"
: "${MYSQL_LOCAL_PORT:?MYSQL_LOCAL_PORT required}"
: "${MYSQL_HOST:?MYSQL_HOST required}"
: "${EXPECTED_MYSQL_HOST:?EXPECTED_MYSQL_HOST required}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE required}"
: "${ONBOARDING_ROLLBACK_FILE:?ONBOARDING_ROLLBACK_FILE required}"
: "${PROD_ONBOARDING_TRANSFORM_APPROVED:?Explicit approval required}"

[[ "$MYSQL_HOST" == "$EXPECTED_MYSQL_HOST" ]] || {
  echo '::error::Unexpected MySQL endpoint'
  exit 1
}
[[ "$MYSQL_DATABASE" == needu ]] || {
  echo '::error::Unexpected database'
  exit 1
}
[[ "$PROD_ONBOARDING_TRANSFORM_APPROVED" == YES ]] || {
  echo '::error::Production onboarding transform was not explicitly approved'
  exit 1
}

python3 - <<'PY'
import os
import json
import sys

import pymysql


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


def scalar(cursor, query):
    cursor.execute(query)
    return int(cursor.fetchone()[0] or 0)


def test_account_state(cursor):
    cursor.execute(
        """
        SELECT COUNT(*),
               COALESCE(SUM(status = 'ACTIVE'), 0),
               COALESCE(SUM(onboarding_completed = 1), 0),
               COALESCE(SUM(taste_analysis_completed = 1), 0)
        FROM users
        WHERE external_id < 0
        """
    )
    return tuple(int(value or 0) for value in cursor.fetchone())


try:
    with connection.cursor() as cursor:
        cursor.execute("SELECT DATABASE(), @@hostname, @@read_only")
        database, hostname, read_only = cursor.fetchone()
        if database != "needu" or read_only:
            raise RuntimeError("Connected to the wrong or read-only MySQL database")
        print(f"Connected database={database}, server={hostname}", flush=True)

        cursor.execute("SET TRANSACTION ISOLATION LEVEL READ COMMITTED")
        cursor.execute("START TRANSACTION")
        eligible_before = scalar(
            cursor,
            "SELECT COUNT(*) FROM users WHERE external_id IS NULL OR external_id >= 0",
        )
        test_users_before = scalar(
            cursor, "SELECT COUNT(*) FROM users WHERE external_id < 0"
        )
        if eligible_before == 0:
            raise RuntimeError("No non-test users found; refusing an empty transform")
        test_state_before = test_account_state(cursor)
        print(f"Non-test users to transform={eligible_before}", flush=True)
        print(f"Excluded test users (external_id < 0)={test_users_before}", flush=True)

        cleanup_tables = (
            "user_taste_profiles",
            "personal_recommendations",
            "gift_recommendations",
            "ai_messages",
        )
        cleanup_counts = {
            table: scalar(cursor, f"SELECT COUNT(*) FROM `{table}`")
            for table in cleanup_tables
        }
        rooms_to_expire = scalar(
            cursor,
            """
            SELECT COUNT(*) FROM ai_chat_rooms
            WHERE status IN ('PENDING', 'ACTIVE', 'ANALYZING')
            """,
        )
        print(f"Rows to delete={cleanup_counts}", flush=True)
        print(f"In-progress rooms to expire={rooms_to_expire}", flush=True)

        cursor.execute(
            """
            SELECT id, status, onboarding_completed, taste_analysis_completed
            FROM users
            WHERE external_id IS NULL OR external_id >= 0
            FOR UPDATE
            """
        )
        previous_users = [
            {
                "id": int(user_id),
                "status": status,
                "onboarding_completed": int(onboarding_completed),
                "taste_analysis_completed": int(taste_analysis_completed),
            }
            for user_id, status, onboarding_completed, taste_analysis_completed
            in cursor.fetchall()
        ]
        rollback_path = os.environ["ONBOARDING_ROLLBACK_FILE"]
        with open(rollback_path, "w", encoding="utf-8") as rollback_file:
            json.dump(previous_users, rollback_file)
        os.chmod(rollback_path, 0o600)

        cursor.execute(
            """
            UPDATE users
            SET status = CASE WHEN status = 'ACTIVE' THEN 'ONBOARDING' ELSE status END,
                onboarding_completed = 0,
                taste_analysis_completed = 0
            WHERE external_id IS NULL OR external_id >= 0
            """
        )
        print(f"User rows matched={cursor.rowcount}", flush=True)

        cursor.execute("SET NAMES utf8mb4")
        cursor.execute(
            """
            UPDATE products
            SET category = CASE category
                WHEN '패션의류/잡화' THEN 'FASHION'
                WHEN '뷰티' THEN 'BEAUTY'
                WHEN '식품' THEN 'FOOD'
                WHEN '헬스/건강식품' THEN 'HEALTH'
                WHEN '주방용품' THEN 'LIVING'
                WHEN '생활용품' THEN 'LIVING'
                WHEN '홈인테리어' THEN 'LIVING'
                WHEN '가전디지털' THEN 'DIGITAL'
                WHEN '스포츠/레저' THEN 'SPORTS'
                WHEN '도서/음반/DVD' THEN 'BOOKS_TICKETS'
                WHEN '반려동물용품' THEN 'PET'
                WHEN '쌀/잡곡' THEN 'FOOD'
                WHEN '과일' THEN 'FOOD'
                WHEN '채소' THEN 'FOOD'
                WHEN '정육/계란' THEN 'FOOD'
                WHEN '수산물' THEN 'FOOD'
                WHEN '우유/유제품' THEN 'FOOD'
                WHEN '냉장/냉동/간편식' THEN 'FOOD'
                WHEN '라면/면류' THEN 'FOOD'
                WHEN '생수/음료' THEN 'FOOD'
                WHEN '커피/차' THEN 'FOOD'
                WHEN '과자/간식' THEN 'FOOD'
                WHEN '세제/청소' THEN 'LIVING'
                WHEN '화장지/위생' THEN 'LIVING'
                WHEN '반려동물' THEN 'PET'
            END
            WHERE category IN (
                '패션의류/잡화', '뷰티', '식품', '헬스/건강식품', '주방용품',
                '생활용품', '홈인테리어', '가전디지털', '스포츠/레저',
                '도서/음반/DVD', '반려동물용품', '쌀/잡곡', '과일', '채소',
                '정육/계란', '수산물', '우유/유제품', '냉장/냉동/간편식',
                '라면/면류', '생수/음료', '커피/차', '과자/간식', '세제/청소',
                '화장지/위생', '반려동물'
            )
            """
        )
        korean_categories_updated = cursor.rowcount
        cursor.execute(
            """
            UPDATE products
            SET category = NULL
            WHERE category IN ('자동차용품', '출산/유아동', '완구/취미', '문구/오피스')
            """
        )
        unsupported_categories_cleared = cursor.rowcount
        cursor.execute(
            """
            UPDATE products
            SET category = UPPER(category)
            WHERE category COLLATE utf8mb4_bin IN (
                'voucher', 'living', 'beauty', 'fashion', 'food', 'digital',
                'health', 'luxury', 'books_tickets', 'sports', 'pet'
            )
            """
        )
        lowercase_categories_updated = cursor.rowcount
        print(
            "Product categories transformed: "
            f"Korean={korean_categories_updated}, "
            f"unsupported-to-NULL={unsupported_categories_cleared}, "
            f"lowercase-codes={lowercase_categories_updated}",
            flush=True,
        )

        for table in cleanup_tables:
            cursor.execute(f"DELETE FROM `{table}`")
            print(f"Deleted {table} rows={cursor.rowcount}", flush=True)

        cursor.execute(
            """
            UPDATE ai_chat_rooms
            SET status = 'EXPIRED',
                active_user_id = NULL,
                updated_at = UTC_TIMESTAMP(6)
            WHERE status IN ('PENDING', 'ACTIVE', 'ANALYZING')
            """
        )
        print(f"Expired in-progress chat rooms={cursor.rowcount}", flush=True)

        invalid_non_test_users = scalar(
            cursor,
            """
            SELECT COUNT(*) FROM users
            WHERE (external_id IS NULL OR external_id >= 0)
              AND (status = 'ACTIVE'
                   OR NOT (onboarding_completed <=> 0)
                   OR NOT (taste_analysis_completed <=> 0))
            """,
        )
        test_state_after = test_account_state(cursor)
        cleanup_counts_after = {
            table: scalar(cursor, f"SELECT COUNT(*) FROM `{table}`")
            for table in cleanup_tables
        }
        in_progress_rooms_after = scalar(
            cursor,
            """
            SELECT COUNT(*) FROM ai_chat_rooms
            WHERE status IN ('PENDING', 'ACTIVE', 'ANALYZING')
            """,
        )
        invalid_categories = scalar(
            cursor,
            """
            SELECT COUNT(*) FROM products
            WHERE category IS NOT NULL
              AND category COLLATE utf8mb4_bin NOT IN (
                  'VOUCHER', 'LIVING', 'BEAUTY', 'FASHION', 'FOOD', 'DIGITAL',
                  'HEALTH', 'LUXURY', 'BOOKS_TICKETS', 'SPORTS', 'PET'
              )
            """,
        )
        if invalid_non_test_users != 0:
            raise RuntimeError(
                f"Non-test user validation failed: {invalid_non_test_users} rows remain active/completed"
            )
        if test_state_after != test_state_before:
            raise RuntimeError("Excluded test-user state changed unexpectedly")
        if any(cleanup_counts_after.values()):
            raise RuntimeError(f"Data cleanup validation failed: {cleanup_counts_after}")
        if in_progress_rooms_after != 0:
            raise RuntimeError(
                f"Chat-room expiration validation failed: {in_progress_rooms_after} rooms remain in progress"
            )
        if invalid_categories != 0:
            raise RuntimeError(
                f"Product category validation failed: {invalid_categories} unsupported category rows remain"
            )

        connection.commit()
        print("PROD_DATA_TRANSFORM_COMMITTED", flush=True)
        print(f"Deleted data row counts={cleanup_counts}", flush=True)
        print(f"Expired chat rooms={rooms_to_expire}", flush=True)
        print("Excluded test-user state was preserved", flush=True)
except Exception as exc:
    try:
        connection.rollback()
    finally:
        print(
            f"::error::Production onboarding transform failed; transaction rolled back: {exc}",
            file=sys.stderr,
        )
    sys.exit(1)
finally:
    connection.close()
PY
