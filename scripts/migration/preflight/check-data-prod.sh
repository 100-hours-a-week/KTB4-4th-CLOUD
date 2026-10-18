#!/usr/bin/env bash
set -uo pipefail

source "$(dirname "$0")/../common/common.sh"

: "${PREFLIGHT_RESULT_DIR:?PREFLIGHT_RESULT_DIR is required}"
: "${MYSQL_USERNAME:?MYSQL_USERNAME is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"
: "${MYSQL_LOCAL_PORT:?MYSQL_LOCAL_PORT is required}"
: "${POSTGRES_USERNAME:?POSTGRES_USERNAME is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_LOCAL_PORT:?POSTGRES_LOCAL_PORT is required}"

mysql_value() {
  MYSQL_PWD="$MYSQL_PASSWORD" mysql --protocol=tcp \
    -h 127.0.0.1 -P "$MYSQL_LOCAL_PORT" -u "$MYSQL_USERNAME" \
    --batch --skip-column-names needu -e "$1" 2>/dev/null
}

postgres_value() {
  PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h 127.0.0.1 -p "$POSTGRES_LOCAL_PORT" -U "$POSTGRES_USERNAME" \
    -d needu_vector -Atqc "$1" 2>/dev/null
}

require_equal "Prod MySQL table count" 22 \
  "$(mysql_value "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='needu';" || true)"

if [[ ! -s "$PREFLIGHT_RESULT_DIR/dms.json" ]]; then
  record_check "Prod MySQL DMS evidence" FAIL "dms.json is missing"
else
  while IFS=$'\t' read -r table expected; do
    actual="$(mysql_value "SELECT COUNT(*) FROM \`${table}\`;" || true)"
    require_equal "Prod MySQL $table rows" "$expected" "$actual"
  done < <(jq -r '
    .TableStatistics[]
    | [.TableName, ((.FullLoadRows // 0) + (.AppliedInserts // 0) - (.AppliedDeletes // 0))]
    | @tsv
  ' "$PREFLIGHT_RESULT_DIR/dms.json")
fi

require_equal "Prod PostgreSQL catalog_embedding_models rows" 1 \
  "$(postgres_value 'SELECT COUNT(*) FROM catalog_embedding_models;' || true)"
require_equal "Prod PostgreSQL catalog_product_documents rows" 20289 \
  "$(postgres_value 'SELECT COUNT(*) FROM catalog_product_documents;' || true)"
require_equal "Prod PostgreSQL catalog_products rows" 7969 \
  "$(postgres_value 'SELECT COUNT(*) FROM catalog_products;' || true)"
require_equal "Prod PostgreSQL catalog_sync_runs rows" 0 \
  "$(postgres_value 'SELECT COUNT(*) FROM catalog_sync_runs;' || true)"
require_equal "Prod PostgreSQL embedding type" 'vector(1024)' \
  "$(postgres_value "SELECT format_type(a.atttypid,a.atttypmod) FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid WHERE c.relname='catalog_product_documents' AND a.attname='embedding' AND NOT a.attisdropped;" || true)"
require_equal "Prod PostgreSQL HNSW cosine index" 1 \
  "$(postgres_value "SELECT COUNT(*) FROM pg_indexes WHERE tablename='catalog_product_documents' AND indexdef ILIKE '%USING hnsw%' AND indexdef ILIKE '%vector_cosine_ops%';" || true)"
