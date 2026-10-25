# T2 MySQL Write API load test (Staging only)

Tests two APIs independently: `POST /api/v1/analytics/product-link-clicks` (204) and `PUT /api/v1/friends/{friendUserId}/favorite` (200).

## Preparation

1. On Mac, establish SSM port forwarding to Staging RDS on `127.0.0.1:13306` in another terminal.
2. From `t2-write/`, run `bash scripts/export-fixtures.sh` (MySQL password prompted twice).
3. Run `python3 scripts/generate-tokens.py` and enter the **Base64-encoded Staging Backend JWT_SECRET** without pasting it into chat. Standard Python only; PyJWT not required. Tokens expire after 3 hours.
4. Set approved `BASE_URL` (V2 Staging only), then smoke-test **one request**:
   `BASE_URL=https://YOUR-STAGING-DOMAIN T2_TARGET=insert RATE=1 DURATION=1s PRE_ALLOCATED_VUS=1 MAX_VUS=1 k6 run scenarios/write.js`
   Repeat with `T2_TARGET=update`. Confirm actual MySQL changes before load.

## Staged test

Example (only after smoke verification):
`BASE_URL=https://YOUR-STAGING-DOMAIN T2_TARGET=insert RATE=5 DURATION=3m PRODUCT_OFFSET=1 k6 run scenarios/write.js`

Suggested INSERT offsets per stage (5,10,20,50,100 RPS, 3 min each): `1, 5, 12, 25, 56`. The offset is **per-user sequence offset**. Avoid reusing offsets within the one-hour deduplication window; 1h resets or distinct offsets are necessary for retests. Do not mix INSERT and UPDATE in one run. For UPDATE, each new test stage starts its sequence from 0 and can repeat previous state: reset favorites to FALSE before the stage or verify actual DB changed-row counts, not only 200 responses.

## Important limitations

- **Each write iteration also calls GET /api/v1/auth/csrf.** Thus `RATE` means write requests/sec, not total HTTP RPS. The CSRF GET adds roughly the same number of requests. Check its rate limit separately.
- Per-user 30/min rate limit: at 100 RPS and 300 users, mean 20/min/user; verify whether the limit is shared across endpoints and whether CSRF counts.
- The UPDATE true/false alternation uses global iteration ordering, **not guaranteed commit ordering** under concurrency. Check DB-level updates before claiming actual UPDATE throughput. The 200 response alone is insufficient.
- HTTP thresholds apply to tagged write endpoints only. Verify 401/403/429 and CSRF failures explicitly; check `checks` too.
- `users.json` includes signed JWTs: never commit or share it. Rotate/recreate after expiry.
- Test data must be removed with the Backend-approved cleanup script **only after** load testing is finished.
