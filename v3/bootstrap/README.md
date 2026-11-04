# NeedU V3 Bootstrap (Dev Apply Role)

이 폴더는 기존 `NeedU-V3-Terraform-Dev` IAM Role 및 인라인 정책 3개를 **재생성하지 않고** Terraform으로 관리하기 위한 템플릿입니다.

## 사용 전 주의
- `v3/bootstrap/`으로 복사하세요. 기존 `terraform/bootstrap/`(V2)은 변경하지 마세요.
- **현재 IAM 정책 전문은 대화에서 일부 잘려 있었으므로 이 ZIP에는 포함하지 않았습니다.** 반드시 AWS에서 직접 가져와야 합니다.
- 기존 Role과 인라인 정책은 먼저 Import합니다. **Import 전에 `terraform apply`를 실행하지 마세요.**
- 이 ZIP은 IAM 권한을 자동 추가하지 않습니다. 먼저 무변경 Plan을 확인한 후 필요한 권한만 추가하세요.
- S3 State `v3/bootstrap/terraform.tfstate`가 기존에 다른 Terraform State로 사용되지 않는지 확인하세요.
- 기존 IAM Role의 별도 관리 주체가 있다면 Import 전에 소유권을 합의하세요.

## 실행 순서
```bash
# repo 루트에서
mkdir -p v3/bootstrap
cp -R /path/to/needu-v3-bootstrap/. v3/bootstrap/
cd v3/bootstrap

# AWS SSO 세션이 유효해야 함
aws sso login --profile needu-v2
bash fetch-current-policies.sh

# 출력된 정책 JSON을 확인하고 백업한 뒤 진행
AWS_PROFILE=needu-v2 bash import-existing.sh
```

`import-existing.sh`는 Import 후 Plan만 실행하고 **Apply는 실행하지 않습니다**. `terraform plan`에서 Role/정책 삭제·교체 또는 예상치 못한 변경이 없어야 합니다.

## 누락된 Security Group 권한 추가
현재 V3 Apply 오류: `ec2:AuthorizeSecurityGroupIngress` 권한 없음.

`policies/TerraformV3Apply.json`의 기존 Statement를 보존하고 다음 Statement를 **추가**하세요(동일 Sid 중복 금지):

```json
{
  "Sid": "ManageDevEksApiSecurityGroupIngress",
  "Effect": "Allow",
  "Action": [
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupIngress"
  ],
  "Resource": "arn:aws:ec2:ap-northeast-2:919551759796:security-group/sg-01bfc1ffedbc000f3"
}
```

추가 후 `terraform plan`으로 **정책 변경만 발생하는지** 확인하고, Bootstrap Admin 프로필로 `terraform apply` 하세요. 실제 V3 Dev Apply는 별도로 새 Workflow 실행을 통해 재시도합니다.

> SG 권한은 SG 리소스뿐 아니라 SG Rule 리소스에 대한 평가가 필요할 수 있습니다. IAM 오류의 정확한 리소스와 조건을 확인하고 최소 권한으로 조정하세요. 기존 IAM 정책에 다른 권한이 포함되어 있다면 유지하세요.

## 보안
- `policies/*.json`에는 계정 정보와 IAM 정책이 들어갑니다. Git 커밋 전 검토하세요.
- `*.tfstate`, `*.tfplan`, `.terraform/`은 커밋하지 마세요.
- Import 시 AWS 권한과 S3 Backend 접근이 필요합니다.
