
# ============================================================
# NeedU V2 Dev - SSM Bastion
#
# Architecture:
# MacBook (DBeaver)
#   -> AWS SSM Session Manager
#   -> Bastion EC2 (Public Subnet)
#   -> RDS MySQL      : 3306
#   -> RDS PostgreSQL : 5432
#
# SSH inbound is not required.
# ============================================================


# ------------------------------------------------------------
# 1. Local Variables
# ------------------------------------------------------------

locals {
  ssm_bastion_name = "needu-dev-ssm-bastion"

  ssm_bastion_vpc_id    = "vpc-0f2478c01e376b1b6"
  ssm_bastion_subnet_id = "subnet-0d83afd6ba8e27647"

  ssm_bastion_mysql_sg    = "sg-000745c3009e4ae53"
  ssm_bastion_postgres_sg = "sg-01eb272724fd8c8d1"
}


# ------------------------------------------------------------
# 2. Amazon Linux 2023 AMI
# ------------------------------------------------------------

data "aws_ami" "ssm_bastion" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# ------------------------------------------------------------
# 3. IAM Assume Role Policy
# ------------------------------------------------------------

data "aws_iam_policy_document" "ssm_bastion_assume" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


# ------------------------------------------------------------
# 4. SSM Bastion Permissions Boundary
#
# Separate from the ECS Runtime Permissions Boundary.
# Limits the maximum permissions of the EC2 IAM Role.
# ------------------------------------------------------------

data "aws_iam_policy_document" "ssm_bastion_boundary" {
  statement {
    sid    = "AllowSSMManagedInstance"
    effect = "Allow"

    actions = [
      "ssm:UpdateInstanceInformation",

      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",

      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "ssm_bastion_boundary" {
  name        = "NeedU-V2-dev-SSMBastionPermissionsBoundary"
  description = "Permissions boundary for NeedU Dev SSM Bastion"

  policy = data.aws_iam_policy_document.ssm_bastion_boundary.json

  tags = {
    Name = "NeedU-V2-dev-SSMBastionPermissionsBoundary"
  }
}


# ------------------------------------------------------------
# 5. EC2 IAM Role
# ------------------------------------------------------------

resource "aws_iam_role" "ssm_bastion" {
  name = local.ssm_bastion_name

  assume_role_policy = data.aws_iam_policy_document.ssm_bastion_assume.json

  permissions_boundary = aws_iam_policy.ssm_bastion_boundary.arn

  tags = {
    Name = local.ssm_bastion_name
  }
}


# ------------------------------------------------------------
# 6. Attach SSM Managed Instance Policy
# ------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm_bastion" {
  role = aws_iam_role.ssm_bastion.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# ------------------------------------------------------------
# 7. IAM Instance Profile
# ------------------------------------------------------------

resource "aws_iam_instance_profile" "ssm_bastion" {
  name = local.ssm_bastion_name

  role = aws_iam_role.ssm_bastion.name
}


# ------------------------------------------------------------
# 8. Bastion Security Group
#
# Inbound:
#   None
#
# Outbound:
#   TCP 443  -> AWS Systems Manager
#   TCP 3306 -> RDS MySQL
#   TCP 5432 -> RDS PostgreSQL
# ------------------------------------------------------------

resource "aws_security_group" "ssm_bastion" {
  name_prefix = "${local.ssm_bastion_name}-"

  description = "SSM Bastion for NeedU Dev RDS MySQL and PostgreSQL"

  vpc_id = local.ssm_bastion_vpc_id

  tags = {
    Name = local.ssm_bastion_name
  }
}


# ------------------------------------------------------------
# 9. Bastion Outbound - HTTPS (SSM)
# ------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "ssm_bastion_https" {
  security_group_id = aws_security_group.ssm_bastion.id

  description = "HTTPS access to AWS Systems Manager"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  cidr_ipv4 = "0.0.0.0/0"
}


# ------------------------------------------------------------
# 10. Bastion Outbound - MySQL
# ------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "ssm_bastion_mysql" {
  security_group_id = aws_security_group.ssm_bastion.id

  description = "MySQL access to Dev RDS"

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  referenced_security_group_id = local.ssm_bastion_mysql_sg
}


# ------------------------------------------------------------
# 11. Bastion Outbound - PostgreSQL
# ------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "ssm_bastion_postgres" {
  security_group_id = aws_security_group.ssm_bastion.id

  description = "PostgreSQL access to Dev RDS"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  referenced_security_group_id = local.ssm_bastion_postgres_sg
}


# ------------------------------------------------------------
# 12. RDS MySQL Inbound from Bastion
#
# Existing Backend and Catalog Sync rules remain unchanged.
# ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "mysql_from_ssm_bastion" {
  security_group_id = local.ssm_bastion_mysql_sg

  description = "Allow MySQL access from Dev SSM Bastion"

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  referenced_security_group_id = aws_security_group.ssm_bastion.id
}


# ------------------------------------------------------------
# 13. RDS PostgreSQL Inbound from Bastion
#
# Existing AI and Catalog access rules remain unchanged.
# ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "postgres_from_ssm_bastion" {
  security_group_id = local.ssm_bastion_postgres_sg

  description = "Allow PostgreSQL access from Dev SSM Bastion"

  ip_protocol = "tcp"
  from_port   = 5432
  to_port     = 5432

  referenced_security_group_id = aws_security_group.ssm_bastion.id
}


# ------------------------------------------------------------
# 14. Bastion EC2
#
# - Amazon Linux 2023
# - t3.micro
# - Public Subnet
# - Public IPv4 for outbound HTTPS
# - No SSH key
# - IMDSv2 required
# - Encrypted gp3 root volume
# ------------------------------------------------------------

resource "aws_instance" "ssm_bastion" {
  ami           = data.aws_ami.ssm_bastion.id
  instance_type = "t3.micro"

  subnet_id = local.ssm_bastion_subnet_id

  vpc_security_group_ids = [
    aws_security_group.ssm_bastion.id
  ]

  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ssm_bastion.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = {
    Name    = local.ssm_bastion_name
    Purpose = "SSM-RDS-PortForwarding"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm_bastion,

    aws_vpc_security_group_egress_rule.ssm_bastion_https,
    aws_vpc_security_group_egress_rule.ssm_bastion_mysql,
    aws_vpc_security_group_egress_rule.ssm_bastion_postgres,

    aws_vpc_security_group_ingress_rule.mysql_from_ssm_bastion,
    aws_vpc_security_group_ingress_rule.postgres_from_ssm_bastion
  ]
}


# ------------------------------------------------------------
# 15. Outputs
# ------------------------------------------------------------

output "ssm_bastion_instance_id" {
  description = "SSM Bastion EC2 Instance ID"
  value       = aws_instance.ssm_bastion.id
}

output "ssm_bastion_security_group_id" {
  description = "SSM Bastion Security Group ID"
  value       = aws_security_group.ssm_bastion.id
}
