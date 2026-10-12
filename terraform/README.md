# NeedU V2 Terraform

**Status: implementation scaffold requiring AWS/account verification. No `terraform init/validate/plan/apply` has been executed against AWS.** Terraform binary is unavailable in the authoring environment. Read the safety checklist before any apply.

## Architecture

- **V1 Prod:** unchanged EC2 + Compose + host MySQL/PostgreSQL.
- **V1 Staging:** separate EC2 cloned from V1 AMI; **not managed by this Terraform project**. Change environment variables, IAM role, external callbacks and data before starting it.
- **V2 Dev:** smaller, lower task count, same service topology.
- **V2 Staging / V2 Prod:** same module, FE/BE/AI ECS Fargate, public ALB, ECS Service Connect, private RDS MySQL/PostgreSQL, ElastiCache Redis, S3 AI Catalog, CloudWatch and autoscaling. Staging and Prod example sizing is the same; only lifecycle safety and domain differ.
- **Migration rehearsal:** V1 Staging -> AWS DMS Full Load + CDC -> V2 Staging RDS, with ongoing V1 writes and explicit cutover/rollback tests. DMS is opt-in and disabled by default.

## Files

```text
bootstrap/                      # one-time S3 backend bucket
modules/v2-stack/               # network, security, ALB, ECS, RDS, Redis, S3, IAM, DMS
  network.tf security.tf alb.tf
  data.tf iam.tf ecs.tf dms.tf
  variables.tf outputs.tf
environments/dev/                # independent state
  main.tf variables.tf terraform.tfvars.example backend.hcl.example
environments/staging/            # independent state
  main.tf variables.tf terraform.tfvars.example backend.hcl.example
environments/prod/               # independent state
  main.tf variables.tf terraform.tfvars.example backend.hcl.example
.github/workflows/deploy-ecs.example.yml
```

## 0. Prerequisites / mandatory checks

1. Install Terraform >=1.10 and AWS provider ~>6.0. Authenticate with AWS using an appropriately scoped IAM identity. Use separate roles or access boundaries for Staging and Prod.
2. Confirm the **existing** VPC, IGW, Route53 hosted zone, GitHub OIDC provider, and ECR repositories. These resources are **not created or imported** by this scaffold; input their real IDs/ARNs/URIs.
3. Check all CIDRs against existing VPC subnets and route tables. Examples assume VPC CIDR `10.0.0.0/16`; do not apply overlapping subnets.
4. ACM certificate must be in ap-northeast-2 and cover the requested domain. Do not use the V1 production domain for V2 before planned cutover.
5. Check RDS supported **exact** MySQL/PostgreSQL engine versions and ElastiCache node types for ap-northeast-2. `16.6` in the example is a placeholder, **not a confirmed supported version**.
6. Ensure images with the chosen immutable SHA tags exist in the three ECR repositories; the images must expose FE 3000, BE 8080, AI 8000. Confirm BE health endpoint `/actuator/health` and FE `/` return expected status.
7. Supply the actual application environment variables and secret references. Names shown are illustrative; validate Spring/Next.js/FastAPI config keys. Secrets should be created **outside Terraform** and injected using `app_secret_parameters` (SSM/Secrets Manager ARNs), not plaintext `.tfvars`. RDS-generated DB passwords are injected from Secrets Manager JSON key `password`.
8. Verify Next.js `NEXT_PUBLIC_*` variables: they may be baked into the image at build time, preventing safe promotion of one digest across environments. Prefer runtime config or a documented environment-specific build exception.
9. Check Redis client support for TLS (`transit_encryption_enabled=true`). `enable_redis_auth=false` means no Redis AUTH token is configured; add authentication policy appropriate for production. If you enable auth, passing `redis_auth_token` through Terraform **stores the value in Terraform state**; prefer a separately managed secret workflow and avoid putting production tokens in tfvars.
10. Staging/Prod ElastiCache is 2-node Multi-AZ and RDS is Single-AZ as assumed; confirm actual V2 Prod target configuration. Staging should mirror whatever Prod configuration is finally selected.
11. This uses ECS tasks in **public subnets with public IP** to avoid NAT charges; task inbound traffic is restricted via security groups, but tasks have internet-reachable network interfaces. Review this tradeoff. Production hardening may move ECS to private subnets with NAT/VPC endpoints; apply identically to Staging.
12. CloudWatch alarm SNS topic ARN is optional. ALB access logging is disabled in this version; enable logging after configuring a bucket with appropriate ELB delivery policy. Additional service-specific SLI alarms and dashboards should be added before production use.
13. IAM CD role currently trusts **one GitHub repository** with a matching GitHub Environment. If FE/BE/AI live in separate repositories, extend `github_repository` to a list and trust each explicitly before deploying. Protect `prod` GitHub Environment with reviewers.
14. Batch task definitions are templates only: the **actual commands / separate Batch Dockerfiles / scheduler** must be implemented with the BE and AI teams. Running these task definitions without overrides may launch normal servers rather than execute a job. No EventBridge schedule is created because job cadence was not specified.
15. `lifecycle.ignore_changes = [task_definition, desired_count]` makes CD and ECS Auto Scaling the owners of live image revisions and task counts. Terraform creates the initial definition but subsequent image deployments occur through CD. Keep the initial image tags current for new environments.
16. RDS PostgreSQL `pgvector` extension must be installed in the database after creation (`CREATE EXTENSION IF NOT EXISTS vector;`) with suitable privileges and supported extension version. Terraform only provisions RDS, not SQL schemas, extensions or data.
17. A newly created RDS database has **no application tables**. Apply schema migrations and import data before deploying healthy app tasks. With `desired_count > 0`, an initial ECS rollout can fail health checks until DB and secrets are ready. Consider creating DB first via `-target` only for controlled bootstrap, then run the full plan.
18. RDS master secret is managed by RDS/Secrets Manager. Ensure IAM permission for the ECS execution role and the runtime task role if your app reads Secrets Manager at runtime.

## 1. Create the Terraform state bucket (one time)

```bash
cd bootstrap
terraform init
terraform plan -var='state_bucket_name=REPLACE_WITH_GLOBALLY_UNIQUE_BUCKET'
terraform apply -var='state_bucket_name=REPLACE_WITH_GLOBALLY_UNIQUE_BUCKET'
```

State bucket has versioning, SSE-S3, public access block, and an HTTPS-only policy. For strict access controls, add a bucket policy limiting access to environment-specific Terraform roles and CI principals. Terraform state may contain sensitive information; never publish it.

## 2. Prepare V2 Staging

```bash
cd environments/staging
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# Edit backend.hcl and terraform.tfvars with verified account-specific values.
terraform fmt -recursive ../../
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars -out=staging.tfplan
terraform show staging.tfplan
# Only after human review:
terraform apply staging.tfplan
```

Use the corresponding `environments/dev` or `environments/prod` folder for independent state. **Do not apply Prod until migration/cutover is explicitly planned**. Prod sample DNS points at `v2-prod.needu.gift` to avoid overwriting V1's `needu.gift` record.

## 3. Migration rehearsal: V1 Staging -> V2 Staging

**Phase A – Prepare V1 Staging**

- Clone the V1 EC2 with an AMI; verify the included EBS volumes, DB consistency, and independent configuration. Do not let the clone send production notifications or reuse production OAuth callbacks.
- Verify MySQL `log_bin=ON`, `binlog_format=ROW`, appropriate `binlog_row_image`, binlog retention and a CDC-capable account. Check PostgreSQL `wal_level=logical`, replication slots, WAL retention, replication account and primary keys/replica identity.
- Test V1 Staging's sustained INSERT/UPDATE/DELETE workload and measure baseline success rate/latency.

**Phase B – Prepare V2 Staging target**

- Create the RDS targets, security groups, and V2 services. Confirm V1 Staging and DMS can communicate over private VPC addresses.
- Prepare PostgreSQL pgvector, DB schemas, indexes, constraints, users, extensions and migration compatibility. DMS does **not** automatically migrate every DDL object, extension, vector index, stored procedure or sequence state.
- Create AWS Secrets Manager secrets for DMS source credentials. Create the `dms-vpc-role` / `dms-cloudwatch-logs-role` IAM roles required by your chosen DMS setup, and a role trusted by `dms.ap-northeast-2.amazonaws.com` with `secretsmanager:GetSecretValue` for all four source/target secrets. Supply its ARN as `dms_endpoint_access_role_arn`. Check current DMS service role requirements.
- On the **V1 Staging** EC2 security group, allow inbound TCP 3306 and 5432 **from the DMS security group**, and configure MySQL/PostgreSQL to listen on the correct private interfaces. No public database ingress.
- Set `enable_dms=true` and populate `dms_source_*` hostnames and Secrets Manager ARNs. Run a new plan and review DMS instance/endpoints/tasks. Terraform creates tasks **stopped**; start only after endpoint connection tests.

**Phase C – Test CDC and cutover**

1. Run initial load + CDC for MySQL and PostgreSQL, with a **continuous V1 Staging write workload**.
2. Monitor DMS `CDCLatencySource` and `CDCLatencyTarget`, source DB logs, target table counts and sampled row checksums.
3. Reconcile IDs, foreign keys, NULLs, timestamps, Unicode, decimal values, sequences, and pgvector records. Test UPDATE and DELETE, not just INSERT.
4. Perform an explicit cutover protocol: pause/fence writes or use an engineered zero-write-loss alternative, drain in-flight requests, wait for CDC lag to reach zero, switch V2 traffic, then resume writes. Record the duration of any write pause and request errors.
5. Test rollback after V2 begins accepting new writes. **One-way CDC cannot safely roll back new V2 writes by itself.** Define a reverse sync or rollback restriction before claiming rollback is safe.

**Important:** `Full Load + CDC` alone does not prove zero downtime. Measure user-facing error rate, successful writes, consistency, cutover delay and rollback safety. For PostgreSQL with pgvector, validate AWS DMS compatibility with the extension-specific data types before assuming automatic replication; some data may need a separate ETL/rebuild process.

## 4. CI/CD integration

The example workflow `.github/workflows/deploy-ecs.example.yml` is a template. Copy it into the appropriate app repository, configure GitHub Environments `dev`, `staging`, `prod`, and set Environment Variables `AWS_ECS_CD_ROLE_ARN`, `ECR_REPOSITORY_URI`. CI builds/pushes immutable SHA images; CD registers a new task definition revision and updates ECS. Promotion should deploy the **same digest** from Staging to Prod, not rebuild with different contents. Add manual approval to Prod.

## 5. Known incomplete production integrations

This is a full **infrastructure scaffold**, not a verified production deployment. Before a live rollout, finish: (a) app-specific environment variable mapping, health paths, and Batch commands, (b) secrets and Redis authentication handling, (c) actual supported versions and CIDRs, (d) DMS IAM roles and DB CDC configuration, (e) CloudWatch application SLI/SLO alarms, (f) app schema migrations and pgvector, (g) Prod DNS cutover procedure and data rollback strategy, (h) AWS cost estimation and quotas, (i) CI/CD trust for separate FE/BE/AI repos, and (j) end-to-end integration testing. These cannot be safely inferred from the available architecture summary.

### CI IAM note

A sample GitHub OIDC ECR CI role is included, trusting `main` and `develop` branches in the **single** `github_repository` input. Because NeedU has separate FE/BE/AI codebases, replace this trust configuration with the actual repository allowlist and GitHub Environment model before use. Existing ECR repositories are referenced; this project does not create, import, or delete them.
