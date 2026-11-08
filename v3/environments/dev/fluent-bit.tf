# Fluent Bit - CloudWatch Logs
resource "aws_cloudwatch_log_group" "fluent_bit" {
  name              = "/needu/v3/dev/eks/application"
  retention_in_days = 14

  tags = {
    Name        = "${module.eks.cluster_name}-application-logs"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# EKS Pod Identity Trust Policy
data "aws_iam_policy_document" "fluent_bit_assume" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# Fluent Bit IAM Role
resource "aws_iam_role" "fluent_bit" {
  name               = "${module.eks.cluster_name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume.json
}

# CloudWatch Logs 최소 쓰기 권한
data "aws_iam_policy_document" "fluent_bit_logs_write" {
  statement {
    sid    = "WriteDevEKSLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = [
      "${aws_cloudwatch_log_group.fluent_bit.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "fluent_bit_logs_write" {
  name   = "WriteNeedUV3DevEKSLogs"
  role   = aws_iam_role.fluent_bit.name
  policy = data.aws_iam_policy_document.fluent_bit_logs_write.json
}

# Fluent Bit Pod Identity
resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = module.eks.cluster_name
  namespace       = "monitoring"
  service_account = "fluent-bit"
  role_arn        = aws_iam_role.fluent_bit.arn

  depends_on = [
    aws_iam_role_policy.fluent_bit_logs_write
  ]
}