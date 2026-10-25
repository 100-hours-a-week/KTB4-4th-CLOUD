#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
HOST="${MYSQL_HOST:-127.0.0.1}"
PORT="${MYSQL_PORT:-13306}"
USER="${MYSQL_USER:-needu}"
command -v mysql >/dev/null || { echo 'mysql 클라이언트가 필요합니다.' >&2; exit 1; }
# Password is requested by mysql; never embed it in the script.
mysql -h "$HOST" -P "$PORT" -u "$USER" -p --batch --raw --skip-column-names needu -e "
SELECT u.id, f.friend_user_id, f.is_favorite
FROM users u JOIN friends f ON f.owner_user_id=u.id
WHERE u.external_id BETWEEN -700000000300 AND -700000000001
AND u.nickname=CONCAT('t2-write-loadtest-', LPAD(-u.external_id-700000000000,3,'0'))
ORDER BY u.external_id DESC;" > config/users.tsv
mysql -h "$HOST" -P "$PORT" -u "$USER" -p --batch --raw --skip-column-names needu -e "
SELECT id FROM products WHERE status='ACTIVE' AND deleted_at IS NULL ORDER BY id;" > config/products.tsv
python3 - <<'PY'
import json, pathlib
p=pathlib.Path('config')
rows=[line.split('\t') for line in (p/'users.tsv').read_text().splitlines() if line.strip()]
assert len(rows)==300, f'expected 300 user mappings, got {len(rows)}'
users=[{'userId':int(a),'friendUserId':int(b),'initialFavorite':bool(int(c))} for a,b,c in rows]
assert len({u['userId'] for u in users})==300
products=[int(line) for line in (p/'products.tsv').read_text().splitlines() if line.strip()]
assert len(products)>=120, f'expected at least 120 products, got {len(products)}'
(p/'users.json').write_text(json.dumps(users,ensure_ascii=False,indent=2))
(p/'products.json').write_text(json.dumps(products))
(p/'users.tsv').unlink(); (p/'products.tsv').unlink()
print(f'Exported {len(users)} users and {len(products)} products. JWT generation is next.')
PY
