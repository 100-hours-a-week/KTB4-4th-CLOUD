# Need U V3 Terraform — 11/2 Mond 작업

기존 V2 Terraform은 **이동하지 않고 유지**합니다. 신규 `v3/`를 별도로 추가합니다.

## 범위
- Dev 전용 VPC / 2 AZ public·private subnets / NAT (신규 VPC를 쓰는 경우의 예시)
- EKS Cluster Terraform Module
- EKS Managed Node Group: system 2개 / application 2개 (11/3 생성 대상)
- VPC CNI는 11/3에 EKS Add-on으로 검증 (Cindy와 담당 구분 확인)

## 실행 전 필수 결정
1. **V2 VPC 재사용 여부**: 이 예시는 **새 V3 VPC**를 만듭니다. 재사용한다면 `module.network`를 제거하고 기존 VPC/Subnet IDs를 입력하도록 수정해야 합니다.
2. 기존 V2 VPC·DB·Valkey와 통신할 경로: 신규 VPC라면 피어링/TGW 등의 연결과 라우팅이 추가로 필요합니다. 기본 파일은 이를 구현하지 않습니다.
3. 2 AZ 이름, CIDR 충돌, NAT 비용, EKS 버전·AMI 호환성, 계정 IAM 권한.
4. **원격 State**: S3 버킷·Key·Locking은 기존 V2 State와 반드시 분리합니다. `backend.tf.example`을 참고하여 설정하세요.
5. `terraform apply` 전에 팀 리뷰 및 비용 확인. 예제는 실제 리소스를 생성하고 과금될 수 있습니다.

## 명령어 (v3/environments/dev)
```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars에 AZ, CIDR, 인스턴스 사양 등 실제 값 입력
terraform fmt -recursive ../../
terraform init -backend=false
terraform validate
# 원격 backend를 설정한 뒤 terraform init 및 terraform plan 진행
```

## 역할
- Mond 11/2: 네트워크 설계, VPC Terraform, EKS Module 코드 및 Plan 준비
- Mond 11/3: EKS/MNG Apply 및 Node Ready 확인
- Cindy: Namespace/RBAC/ServiceAccount, Helm/Dev Values (이 zip에는 포함하지 않음)

> 주의: 샘플 기본값은 설계 초안이지 운영 확정값이 아닙니다. 특히 Node 타입, EKS 버전, NAT 수량은 비용·호환성 확인 후 확정하세요.
