
# V3 Plan Role은 Apply Role과 별도로 생성되어 있다.
# Terraform refresh에 필요한 공통 리소스 조회 권한을 부여한다.
# V3 Dev 환경 종료에 따라 Dev 전용 조회 정책은 제거한다.

resource "aws_iam_role_policy" "v3_plan_state" {
  name   = "TerraformV3State"
  role   = "NeedU-V3-Terraform-Plan"
  policy = file("${path.module}/policies/TerraformV3PlanState.json")
}

resource "aws_iam_role_policy" "v3_plan_resource_read" {
  name   = "TerraformV3ResourceRead"
  role   = "NeedU-V3-Terraform-Plan"
  policy = file("${path.module}/policies/TerraformV3PlanResourceRead.json")
}
