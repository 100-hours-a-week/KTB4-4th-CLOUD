# NeedU Prod Cutover — Issue #137 (안전장치 포함 초안)

## 반드시 읽기

**현재 패키지는 Prod DNS 전환 로직과 안전장치를 구현한 초안이며, V1 Write Gate ON/OFF, DMS 최종 중지, MySQL/PostgreSQL 정합성 검증을 자동화한 완성본이 아닙니다.** 자동 Gate 제어는 V1 Nginx 설정/실제 운영 경로를 확인하지 못했으므로 임의로 만들지 않았습니다. `MIGRATION_*_APPROVED=YES` 같은 GitHub 변수는 증거를 대체하지 않습니다. 수동 확인에 의존하는 상태에서 운영 DNS 전환을 승인하지 마세요.

Prod DNS 전환 전에 반드시: (1) V1 전체 쓰기 경로 차단 및 Gate 503 검증 (2) MySQL 활성 트랜잭션 종료 (3) DMS CDC 최종 동기화·Validation 검증 및 중지 (4) PostgreSQL dump/restore 정합성 확인 (5) V2 ALB에 `needu.gift` API host rule 및 ACM 인증서 적용 (6) V2 FE/BE Task 실행 및 정상 health (7) 운영 승인/복구 계획 완료.

현재 확인된 Prod ECS desiredCount=0, Prod DMS 미구성, ALB API rule `prod.needu.gift`만 존재. `check-prod-readiness.sh`는 `needu.gift` API rule이 없으면 **실패하도록 설계**했습니다.

## 포함 파일

- `.github/workflows/prod-migration-cutover.yml`: 수동 실행, Environment 승인, 별도 Preflight run/commit 검증, DNS 변경 opt-in.
- `scripts/migration/cutover/prod-common.sh`: 계정·리소스 보호, 공통 함수.
- `scripts/migration/cutover/check-prod-readiness.sh`: V1 DNS 원상태, V2 Alias, live-host API rule, FE/BE health 검증.
- `scripts/migration/cutover/verify-v1-gate.sh`: 사전 설계된 부작용 없는 V1 gate 전용 프로브로 503 확인. 전체 쓰기 경로 검증을 대신하지 않음.
- `scripts/migration/cutover/switch-dns-prod.sh`: 별도 승인 플래그 확인 후 Route53 UPSERT, INSYNC 대기, 이전 레코드 증거 저장.
- `scripts/migration/cutover/verify-dns-prod.sh`: Route53 전환 후 Alias 확인. DNS 캐시 종료를 의미하지 않음.

## 적용

저장소 루트 `KTB4-4th-CLOUD`에서:

```bash
git branch --show-current
unzip -l ~/Downloads/needu-prod-cutover-137.zip
unzip -o ~/Downloads/needu-prod-cutover-137.zip -d .
chmod +x scripts/migration/cutover/*-prod.sh scripts/migration/cutover/prod-common.sh
for f in scripts/migration/cutover/*-prod.sh scripts/migration/cutover/prod-common.sh; do bash -n "$f" || exit 1; done
git diff --check
git status --short
```

기존 Staging 파일은 변경하지 않습니다. `prod-migration-cutover.yml`은 Staging에서 복사해 놓은 파일을 덮어씁니다.

## GitHub Environments

`prod-migration-cutover`는 `prod-migration` Preflight와 **별도 Environment**로 생성하고 required reviewers, 배포 브랜치 제한을 설정하세요. Cutover OIDC IAM Role은 `repo:100-hours-a-week/KTB4-4th-CLOUD:environment:prod-migration-cutover`만 허용하고 Route53 권한을 `needu.gift` A 레코드로 제한하는 조건을 검토하세요.

Variables (준비 전에는 값 설정하지 말 것):

- `MIGRATION_CUTOVER_ROLE_ARN`: Prod Cutover 전용 OIDC Role.
- `MIGRATION_APPROVED_PREFLIGHT_RUN_ID`: 동일 Git SHA에서 PASS한 Prod Preflight run ID. 현재 데이터 정합성 미구현으로 PASS 불가.
- `MIGRATION_V1_GATE_PROBE_URL`: 인증된, **부작용 없는** V1 gate 전용 프로브 URL. 실제 쓰기 요청을 수행하는 URL 금지.
- `MIGRATION_DB_CUTOVER_APPROVED`: MySQL 트랜잭션 및 최종 쓰기 정지 확인 후 승인 기록.
- `MIGRATION_FINAL_DMS_VALIDATED`: DMS CDC/validation 완료 및 중지 확인 후 승인 기록.
- `MIGRATION_POSTGRES_VALIDATED`: PostgreSQL 정합성 검증 후 승인 기록.
- `MIGRATION_HUMAN_FINAL_APPROVAL`: 담당자 최종 승인 기록.

**중요**: GitHub Variables에 `YES`만 입력해서 자동 검증이 된다고 오해하면 안 됩니다. 이 부분은 실제 검증 스크립트/서명된 승인 아티팩트와 연결해야 합니다. GitHub Environment 승인은 워크플로 실행 시작 전의 별도 승인입니다.

## 안전한 개발 순서

1. ZIP 적용, `bash -n`, PR 리뷰까지만 진행.
2. V1 Nginx write-gate 방식과 콜백/배치/비HTTP 쓰기 차단 확인.
3. DMS 및 PostgreSQL 검증 스크립트 연동. Preflight fail-closed 유지.
4. ALB `needu.gift` API rule, TLS/쿠키/리다이렉트 설정 반영 후 V2 health 확인.
5. Staging 환경에서 DNS 전환 및 실패 복구 테스트 (Prod 실제 DNS 변경 금지).
6. Prod 승인 후 운영 절차로 Cutover.

`enable_dns_change=false`가 기본값이며, false일 때는 AWS 조회 및 Preflight run 확인만 합니다. **false 실행도 현재 인프라 조건 때문에 실패할 수 있습니다.** true 실행은 실제 DNS 변경을 유발하므로 지금 실행하지 마세요.

## Commit

```bash
git add .github/workflows/prod-migration-cutover.yml scripts/migration/cutover/*-prod.sh scripts/migration/cutover/prod-common.sh
git commit -m "feat: scaffold guarded prod DNS cutover (#137)"
git push -u origin feat/prod-migration-workflow-137
```
