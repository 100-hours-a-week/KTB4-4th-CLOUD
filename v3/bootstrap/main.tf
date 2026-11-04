locals {
  role_name = "NeedU-V3-Terraform-Dev"
}

resource "aws_iam_role" "v3_dev_apply" {
  name               = local.role_name
  assume_role_policy = file("${path.module}/policies/trust.json")
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy" "v3_apply" {
  name   = "TerraformV3Apply"
  role   = aws_iam_role.v3_dev_apply.name
  policy = file("${path.module}/policies/TerraformV3Apply.json")
}
resource "aws_iam_role_policy" "v3_resource_read" {
  name   = "TerraformV3ResourceRead"
  role   = aws_iam_role.v3_dev_apply.name
  policy = file("${path.module}/policies/TerraformV3ResourceRead.json")
}
resource "aws_iam_role_policy" "v3_state" {
  name   = "TerraformV3State"
  role   = aws_iam_role.v3_dev_apply.name
  policy = file("${path.module}/policies/TerraformV3State.json")
}
