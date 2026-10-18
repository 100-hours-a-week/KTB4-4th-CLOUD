# Prod #137 migration implementation notes

## Status: NOT SAFE TO EXECUTE

This package adds real V1 Nginx write-gate SSM execution, dual-DB transaction checks, Prod DMS CDC validation, DMS stop, and Route53 change logic. **DNS mutation remains deliberately blocked** by a post-stop reconciliation step; preflight also remains FAIL-CLOSED until actual SQL-level reconciliation is implemented.

**Do not enable `enable_dns_change`**. If enabled, it can switch the live Nginx gate and stop Prod DMS before the intentional blocker. It is not a harmless dry run.

The production DMS task is not yet known. GitHub Environment vars: `MIGRATION_CUTOVER_ROLE_ARN`, `MIGRATION_APPROVED_PREFLIGHT_RUN_ID`, `MIGRATION_V1_GATE_PROBE_URL`, `MIGRATION_PROD_DMS_TASK_ARN`, `MIGRATION_PROD_DMS_INSTANCE_ID`, `MIGRATION_PROD_DMS_TABLES`, `MIGRATION_DMS_STOP_APPROVED`, and previously defined independent approvals. The IAM role needs SSM SendCommand/GetCommandInvocation, DMS describe/stop, CloudWatch GetMetricStatistics, Route53 change/list, ELB describe, and STS caller identity, scoped to resources.

Before completing: implement *actual* MySQL+PostgreSQL source/target post-stop reconciliation (row count, PK/checksum, successful writes), verify Prod ALB needu.gift routing + ACM SAN, OAuth/cookie/CORS settings, and check internal Batch/AI/direct DB write paths. Implement operator-led recovery plan and rehearse in staging. Never copy staging `transform-policy.sh` into production.

## Apply to repository root

`unzip -o ~/Downloads/needu-prod-137-integration.zip -d .`

`find scripts/migration/cutover -maxdepth 1 -name '*prod*.sh' -exec bash -n {} \;`

`git add .github/workflows/prod-migration-cutover.yml scripts/migration/cutover/ docs/PROD-137-IMPLEMENTATION-NOTES.md`

`git diff --cached --check`

This package intentionally excludes an automatic rollback: DNS rollback alone cannot reverse writes to V2.
