data "aws_partition" "current" {}
data "aws_caller_identity" "eso" {}

# V2와 값을 공유하는 항목만 조회한다. 도메인에 종속된 Redirect URI는 V3 전용 경로를 사용한다.
locals {
  eso_v2_backend_parameters = toset([
    "AI_CHAT_SHORT_COOLDOWN_EXTERNAL_IDS",
    "AI_SERVICE_TOKEN",
    "JWT_SECRET",
    "KAKAO_ADMIN_KEY",
    "KAKAO_CLIENT_SECRET",
    "KAKAO_REST_API_KEY",
    "KAKAO_TOKEN_ENCRYPTION_KEY",
    "SENTRY_DSN",
    "VAPID_PRIVATE_KEY",
    "VAPID_PUBLIC_KEY",
    "VAPID_SUBJECT",
    "WEB_PUSH_ENABLED",
    "WEB_PUSH_REQUEST_TIMEOUT",
    "WEB_PUSH_TTL",
  ])

  eso_v2_ai_parameters = toset([
    "CATALOG_DATABASE_URL_RO",
    "EXTRACTION_MODEL_BASE_URL",
    "EXTRACTION_MODEL_NAME",
    "JUDGMENT_MODEL_BASE_URL",
    "JUDGMENT_MODEL_NAME",
    "OPENROUTER_API_KEY",
    "RESPONSE_MODEL_BASE_URL",
    "RESPONSE_MODEL_NAME",
    "SERVICE_TOKEN",
    "UPSTAGE_API_KEY",
    "RUNPOD_API_KEY",
    "RUNPOD_POD_NAME_PREFIX",
    "MODEL_API_KEY",
    "RESPONSE_FALLBACK_MODEL_BASE_URL",
    "RESPONSE_FALLBACK_MODEL_NAME",
    "EXTRACTION_FALLBACK_MODEL_BASE_URL",
    "EXTRACTION_FALLBACK_MODEL_NAME",
  ])

  eso_ssm_parameter_names = concat(
    ["/needu/v2/prod/frontend-runtime/SENTRY_ENVIRONMENT"],
    [for name in local.eso_v2_backend_parameters : "/needu/v2/prod/backend/${name}"],
    [for name in local.eso_v2_ai_parameters : "/needu/v2/prod/ai/${name}"],
    [
      "/needu/v3/prod/backend/KAKAO_REDIRECT_URI",
      "/needu/v3/prod/backend/KAKAO_FRIEND_REDIRECT_URI",

      # Production 평가용 데모 로그인
      "/needu/v3/prod/backend/DEMO_LOGIN_ENABLED",
      "/needu/v3/prod/backend/AUTH_DEMOLOGIN_ACCOUNTS_*",
    ],
  )

  eso_ssm_parameter_arns = [
    for name in local.eso_ssm_parameter_names :
    "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.eso.account_id}:parameter${name}"
  ]
}

# Secret 값을 읽지 않고, V2 Dev RDS가 관리하는 Secret ARN만 조회한다.
data "aws_db_instance" "eso_mysql" {
  db_instance_identifier = "needu-prod-mysql"
}

data "aws_db_instance" "eso_postgres" {
  db_instance_identifier = "needu-prod-postgres"
}

data "aws_iam_policy_document" "eso_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${module.eks.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.eso_assume.json
}

data "aws_iam_policy_document" "eso_read" {
  statement {
    sid       = "ReadProdParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = local.eso_ssm_parameter_arns
  }

  statement {
    sid     = "ReadProdRDSSecrets"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      data.aws_db_instance.eso_mysql.master_user_secret[0].secret_arn,
      data.aws_db_instance.eso_postgres.master_user_secret[0].secret_arn,
    ]
  }

  dynamic "statement" {
    for_each = length(var.eso_secret_kms_key_arns) > 0 ? [1] : []
    content {
      sid       = "DecryptCustomerManagedKeys"
      actions   = ["kms:Decrypt"]
      resources = var.eso_secret_kms_key_arns
    }
  }
}

resource "aws_iam_role_policy" "eso_read" {
  name   = "ReadNeedUProdApplicationSecrets"
  role   = aws_iam_role.eso.name
  policy = data.aws_iam_policy_document.eso_read.json
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn

  depends_on = [aws_iam_role_policy.eso_read]
}
