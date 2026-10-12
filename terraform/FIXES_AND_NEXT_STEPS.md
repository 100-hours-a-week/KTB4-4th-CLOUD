# NeedU V2 Terraform 수정 내역 및 검증 안내

## 수정
- `.tf` 전체의 잘못된 한 줄 HCL 블록(중첩 블록, 복수 인자)을 여러 줄 블록으로 변경했습니다.
- ECS AI 서비스의 LB 미연결 상태에서 health check grace period가 지정되지 않도록 수정했습니다.
- GitHub Actions 예시에서 서비스별 ECR URI를 AWS 계정/서비스명으로 생성하고, 실제 이미지가 교체되었는지 검사합니다.

## 검증 범위
- 이 작업 환경에는 Terraform 실행 파일 및 AWS Provider 다운로드 네트워크가 없어 `terraform fmt`, `terraform init`, `terraform validate`, `terraform plan`을 직접 실행하지 못했습니다.
- 따라서 **검증 완료/배포 가능 코드로 간주하면 안 됩니다.** 로컬에서 아래 순서로 확인하고 출력되는 오류를 해결해야 합니다.

```bash
terraform fmt -recursive terraform/
terraform fmt -check -recursive terraform/
cd terraform/environments/staging
terraform init -backend=false
terraform validate
```

`init -backend=false`는 원격 State 설정 없이 Provider/Module을 초기화합니다. AWS Provider 설치를 위한 네트워크가 필요합니다.

## 배포 전 필수 확인
- `terraform.tfvars.example`, `backend.hcl.example`은 예시 파일입니다. 실제 값으로 교체하기 전에는 `apply`하지 마세요.
- 기존 VPC/IGW, ACM 인증서, Route53 Zone, ECR, GitHub OIDC Provider를 확인하세요. V1 운영 DNS(`needu.gift`)를 덮어쓰지 마세요.
- DB 엔진 버전/RDS 가용성, pgvector 지원, ElastiCache Redis 호환성, ECS 앱 환경변수/헬스체크/이미지/실제 배치 명령을 검증하세요.
- DMS는 `enable_dms=false`가 기본입니다. Full Load + CDC 전 source/target 자격증명, 논리 복제/binlog, DB SG, DMS 역할, 매핑/DDL 및 CDC cutover를 별도로 검증하세요.
- GitHub Actions 예시는 `.example.yml`로 비활성화되어 있습니다. 실제 CI/CD 저장소와 OIDC `sub` 조건, 환경별 IAM Role을 확인하고 적용하세요.
- 비밀번호/토큰을 `.tfvars`에 직접 저장하지 마세요. State와 실행 로그 접근 권한을 제한하세요.
- `terraform plan`의 기존 운영 리소스 변경/삭제가 없는지 반드시 확인하세요.
