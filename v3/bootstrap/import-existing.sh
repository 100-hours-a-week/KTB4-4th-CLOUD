#!/usr/bin/env bash
set -euo pipefail
ROLE="NeedU-V3-Terraform-Dev"
export AWS_PROFILE="${AWS_PROFILE:-needu-v2}"
terraform init -input=false
terraform import aws_iam_role.v3_dev_apply "$ROLE"
terraform import aws_iam_role_policy.v3_apply "$ROLE:TerraformV3Apply"
terraform import aws_iam_role_policy.v3_resource_read "$ROLE:TerraformV3ResourceRead"
terraform import aws_iam_role_policy.v3_state "$ROLE:TerraformV3State"
terraform plan -out=bootstrap-review.tfplan
terraform show -no-color bootstrap-review.tfplan
