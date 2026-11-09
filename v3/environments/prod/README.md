# NeedU V3 Production EKS Infrastructure

Copy `environments/prod/` and `modules/eks-prod/` into the existing `v3/` folder, preserving relative paths. Existing Dev files/modules are not changed.

## Before any apply

1. Review current VPC subnets and ensure the proposed CIDRs do not overlap reserved ranges or IPAM allocations.
2. Verify the EKS version, EC2 capacity and quotas in all three AZs.
3. Confirm existing V2 public subnet IDs, IGW, IAM administrator role and approved API CIDRs.
4. Ensure the Terraform runner role has production IAM/EKS/EC2/NAT permissions, including PassRole, and regional NAT availability-zone discovery permissions.
5. Verify the S3 backend bucket, lockfile permissions and prod State key.
6. Plan and review costs: Regional NAT auto-mode may allocate addresses across all active AZs; it is not billed like one zonal NAT.
7. This scaffold intentionally excludes ALB Controller, Ingress, WAF, workload IAM/Pod Identity associations, Cluster Autoscaler, Valkey/RDS access, monitoring, and production deployment workflows. Add/verify these before routing production traffic.

## Commands

```bash
cp environments/prod/terraform.tfvars.example environments/prod/terraform.tfvars
# Edit the two REPLACE_WITH values and verify all other settings.
cd environments/prod
terraform init
terraform fmt -recursive . ../../modules/eks-prod
terraform validate
terraform plan -out=prod.tfplan
terraform show -no-color prod.tfplan
```

**Do not apply without reviewing the full plan.**

Regional NAT: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
