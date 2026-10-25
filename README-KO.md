# NeedU Prod Migration Preflight — Issue #137

## 범위

- **조회 전용**: Prod Route 53 현행 A 및 사전검증 Alias, EIP, ALB Rule, ECS, RDS 메타데이터, DMS 상태를 검증합니다.
- **기존 Staging 파일 미변경**. `prod-migration-cutover.yml`은 이 패키지에 포함되지 않습니다.
- **안전한 FAIL-CLOSED**: `check-data-prod.sh`는 MySQL/PostgreSQL 데이터 정합성 검증이 연결될 때까지 의도적으로 FAIL합니다. 따라서 이 버전은 Prod Cutover를 허용하는 최종 Preflight가 아닙니다.
- **현재 의도된 상태**: Prod ECS desired=0, DMS 미구성 → FAIL 정상.

## 적용

저장소 루트에서 압축파일을 다운로드한 위치를 기준으로 다음을 실행하세요.

```bash
git switch feat/prod-migration-workflow-137
unzip -l ~/Downloads/needu-prod-preflight-137.zip
unzip -o ~/Downloads/needu-prod-preflight-137.zip -d .
chmod +x scripts/migration/preflight/*-prod.sh
git status --short
git diff --check
```

이미 `prod-migration-preflight.yml`을 Staging에서 복사한 상태이므로 `unzip -o`가 해당 Prod 파일을 덮어씁니다. 기존 Staging 워크플로는 변경하지 않습니다.

## GitHub Environment / IAM

1. GitHub Repository Settings → Environments → `prod-migration` 생성, required reviewers 지정.
2. Environment Variables:
   - `MIGRATION_PREFLIGHT_ROLE_ARN`: Prod 전용 **조회 권한** OIDC Role ARN (신규 생성/검증 필요)
   - `MIGRATION_DMS_TASK_ID`: Prod DMS Task Identifier (신디가 구성한 뒤 지정; `prod` 포함)
3. AWS OIDC Role trust policy에서 해당 repo + `environment:prod-migration` subject 허용 여부 확인.
4. 조회 권한: `sts:GetCallerIdentity`, `route53:ListResourceRecordSets`, `ec2:DescribeAddresses`, `elasticloadbalancing:Describe*`, `ecs:DescribeServices`, `rds:DescribeDBInstances`, `dms:DescribeReplicationTasks`, `dms:DescribeTableStatistics` 등.
5. Prod Preflight 전용 Role에는 Route 53 UPSERT, ALB ModifyRule, DMS Stop 권한을 부여하지 마세요.

## 반드시 후속 구현할 것

- `check-data-prod.sh`를 실제 MySQL/PostgreSQL SQL/스키마/행 수/PK 및 정합성 검증으로 교체. 검증 완료 전 PASS 불가.
- DMS `ValidationEnabled` 및 CDC 지연, Source/Target Endpoint, Task 상태와 일치 여부를 최종 Cutover 체크에 추가.
- 실제 `needu.gift` 전환 시 Prod ALB가 해당 호스트의 API 라우팅, 인증서, CORS/쿠키를 지원하는지 별도 검증.
- Route 53 DNS 전환, V1 Write Gate, 실패 복구/롤백은 별도 승인된 Prod Cutover 워크플로에서 구현.
- Workflow `concurrency.group`은 Cutover에서도 `prod-migration-control`을 사용하도록 맞출 것.

## 커밋

```bash
git add .github/workflows/prod-migration-preflight.yml scripts/migration/preflight/*-prod.sh scripts/migration/preflight/_prod_common.sh
git commit -m "feat: add read-only prod migration preflight scaffold (#137)"
git push -u origin feat/prod-migration-workflow-137
```

GitHub Actions에서 수동 실행은 IAM/환경 변수 설정 완료 후에만 진행하세요. 현재는 FAIL이 예상됩니다.
