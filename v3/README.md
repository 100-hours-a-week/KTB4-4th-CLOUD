# NeedU V3 Dev EKS — existing V2 VPC

This module reuses V2 VPC `vpc-0f2478c01e376b1b6` and existing Dev public subnets.
It creates V3 private subnets (`10.1.64.0/24`, `10.1.65.0/24`), one NAT Gateway,
one private route table, an EKS cluster, VPC CNI managed add-on, and **four** AZ-specific
Managed Node Groups: one System and one Application group per AZ.

## Node layout

- AZ 2a: System 1 (min 1, max 2), Application 1 (min 1, max 2)
- AZ 2c: System 1 (min 1, max 2), Application 1 (min 1, max 2)
- Initial total: 4 EC2 nodes; maximum: 8 EC2 nodes. These are initial limits,
  **not** load-tested capacity targets. Cluster Autoscaler must be installed separately.
- System nodes are tainted `dedicated=system:NoSchedule`; workloads require tolerations.

## Safety and limitations

- `terraform.tfvars` and `backend.tf` are deliberately **not included** in the ZIP.
  Keep your existing local files. Add `eks_public_access_cidrs` and replace the old
  `system_desired` / `app_desired` variables with the new per-AZ max variables.
- Public EKS API CIDRs must be trusted egress IPs; IP changes may block kubectl access.
- VPC CNI add-on is managed, but CNI IAM policy is **temporarily attached to the node role**.
  Dedicated Pod Identity/IRSA is a follow-up hardening task.
- EKS 1.33 and add-on compatibility, regional quotas, existing public subnet route,
  RDS/ElastiCache security groups, and public subnet ALB discovery tags need verification.
- NAT Gateway is in one AZ; this creates a cross-AZ dependency and charges.
- Terraform only defines infrastructure; no AWS resources have been created by this ZIP.
- AWS managed add-ons `coredns` and `kube-proxy` are not explicitly managed here.
  Check/install them as part of EKS bootstrap before workload deployment.

## Commands (from v3/environments/dev)

```bash
terraform fmt -recursive ../../
terraform init -reconfigure
terraform validate
AWS_PROFILE=needu-v2 terraform plan -out=v3-dev.tfplan
terraform show v3-dev.tfplan
```

Review the plan and confirm no V2 resources are changed or destroyed before apply.
