# NeedU V3 Dev (existing V2 VPC)

Modified from `needu-v3-mond-1102-fixed(1).zip`.
Reuses V2 VPC `vpc-0f2478c01e376b1b6` and Dev public subnets.
Creates 2 V3 private subnets, 1 NAT Gateway + EIP, a private route table,
EKS cluster and System/Application Managed Node Groups.

## Before applying
- Confirm `10.1.64.0/24` and `10.1.65.0/24` are available and approved.
- Configure `environments/dev/backend.tf` from the example using the real S3 bucket and separate state key. Do not apply using unintended local state.
- This does not guarantee one System + one Application node per AZ: each MNG spans both AZs.
- VPC CNI IAM permissions exist in the EKS module; managed Add-on setup and health verification are follow-up tasks.
- Existing Dev RDS SG requires V3 access rules. No VPC peering is needed.
- NAT, EKS, nodes and EIP can incur AWS charges.
- Review existing local or remote Terraform state before overwriting files or applying.

## Commands
```bash
cp v3/environments/dev/terraform.tfvars.example v3/environments/dev/terraform.tfvars
cd v3/environments/dev
terraform fmt -recursive ../../
terraform init -backend=false  # syntax checks only, not apply
terraform validate
AWS_PROFILE=needu-v2 terraform plan
```
Before apply, configure S3 backend and initialize properly; inspect plan carefully.
No new VPC or public subnet should appear in the plan.
