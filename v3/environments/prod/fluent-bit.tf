resource "aws_cloudwatch_log_group" "fluent_bit" {
  name              = "/needu/v3/prod/eks/application"
  retention_in_days = 30

  tags = {
    Name = "${module.eks.cluster_name}-application-logs"
  }
}

data "aws_iam_policy_document" "fluent_bit_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${module.eks.cluster_name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume.json
}

data "aws_iam_policy_document" "fluent_bit_logs_write" {
  statement {
    sid    = "WriteProdEKSLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.fluent_bit.arn}:*"]
  }
}

resource "aws_iam_role_policy" "fluent_bit_logs_write" {
  name   = "WriteNeedUV3ProdEKSLogs"
  role   = aws_iam_role.fluent_bit.name
  policy = data.aws_iam_policy_document.fluent_bit_logs_write.json
}

resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = module.eks.cluster_name
  namespace       = "monitoring"
  service_account = "fluent-bit"
  role_arn        = aws_iam_role.fluent_bit.arn

  depends_on = [aws_iam_role_policy.fluent_bit_logs_write]
}
