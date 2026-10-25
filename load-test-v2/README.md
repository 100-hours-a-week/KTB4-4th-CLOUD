# Need U V2 k6 - V1/V2 comparison

## Purpose
- `scenarios/compare.js`: four GET requests per iteration (friends, friend-detail, personal-recommendations, gift-recommendations). Fixed 1:1:1:1 mix.
- `scenarios/user-flow.js`: existing three-request user journey retained for legacy tests; **not** used for four-API comparison.
- `scenarios/single-api.js`: isolate one API.
- `scenarios/smoke.js`: verify all four APIs.

## Prerequisites
1. Only use an approved V2 **Staging** URL. Do not run load against production.
2. Create `config/tokens.json` from the example with newly issued Staging test-user tokens. Never commit or share tokens.
3. Each test user must have at least one friend and populated recommendation data.
4. Keep V2 Backend Task count fixed and disable Auto Scaling **for comparison only**. Re-enable afterwards.
5. Ensure load-generator resources, API rate limits, monitoring, and a stop/rollback plan are ready.
6. Create `results/` (already included in this package).

## Commands (from project root)
```bash
export BASE_URL='https://YOUR-AUTHORIZED-STAGING-HOST'

k6 run -e BASE_URL="$BASE_URL" scenarios/smoke.js

k6 run -e BASE_URL="$BASE_URL" -e API_TARGET=friends -e RATE=1 -e DURATION=1m scenarios/single-api.js

# 100 HTTP RPS = 25 iterations/s x 4 HTTP requests/iteration
k6 run -e BASE_URL="$BASE_URL" -e RATE=25 -e DURATION=5m -e PRE_ALLOCATED_VUS=100 -e MAX_VUS=500 --summary-export=results/v2-100.json scenarios/compare.js

# 122 HTTP RPS = 30.5 iterations/s x 4 HTTP requests/iteration
k6 run -e BASE_URL="$BASE_URL" -e RATE=305 -e TIME_UNIT=10s -e DURATION=5m -e PRE_ALLOCATED_VUS=100 -e MAX_VUS=500 --summary-export=results/v2-122.json scenarios/compare.js

# 200 HTTP RPS = 50 iterations/s x 4 requests/iteration
k6 run -e BASE_URL="$BASE_URL" -e RATE=50 -e DURATION=5m -e PRE_ALLOCATED_VUS=200 -e MAX_VUS=500 --summary-export=results/v2-200.json scenarios/compare.js

# 250 HTTP RPS = 62.5 iterations/s x 4 requests/iteration
k6 run -e BASE_URL="$BASE_URL" -e RATE=625 -e TIME_UNIT=10s -e DURATION=5m -e PRE_ALLOCATED_VUS=200 -e MAX_VUS=600 --summary-export=results/v2-250.json scenarios/compare.js

# 300 HTTP RPS = 75 iterations/s x 4 requests/iteration (only if prior steps safe)
k6 run -e BASE_URL="$BASE_URL" -e RATE=75 -e DURATION=5m -e PRE_ALLOCATED_VUS=300 -e MAX_VUS=650 --summary-export=results/v2-300.json scenarios/compare.js
```

**Note**: k6 `constant-arrival-rate` accepts numeric `rate` but some versions require integer iteration counts. For portability, use `RATE=305 TIME_UNIT=10s` to produce 30.5 iterations/s (122 HTTP RPS), and `RATE=625 TIME_UNIT=10s` for 62.5 iterations/s (250 HTTP RPS). The compare config uses `TIME_UNIT` when supplied.

## Metrics
- `http_reqs` / test duration: achieved request throughput (use steady-state window; summary averages can include setup/teardown).
- `http_req_failed`: HTTP non-200, including 3xx, as configured.
- `http_req_duration`: p95 <= 300 ms and p99 <= 1000 ms.
- `dropped_iterations`: must be zero for target load delivery.
- Endpoint-specific tags separate the four APIs.
- `setup()` friend discovery requests are outside the timed scenario but may appear in summary; exclude `scenario`-tagged setup traffic when comparing precisely.

## V1 reproducibility caveat
The supplied V1 report lists all four endpoints, but its documented user-flow is **three** requests. Its 100/200/250/300-RPS execution script was not supplied. This package implements a **four-request equal-weight** scenario based on the user's clarification. For a scientifically exact V1/V2 comparison, verify the V1 high-load run used the same four-request ratio, order, duration, timeout, VUs, tokens, and rate-limit policy.

## Security
Previously pasted tokens must be rotated. Never log raw JWTs or response bodies that may contain sensitive data.
