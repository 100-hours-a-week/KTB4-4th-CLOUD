
# ============================================================
# NeedU V2 Dev - SSM Bastion
#
# MacBook / DBeaver
#   -> AWS Systems Manager Session Manager
#   -> SSM Bastion EC2
#   -> Dev RDS MySQL      (3306)
#   -> Dev RDS PostgreSQL (5432)
#
# VPC / Subnet / RDS Security Groups:
#   Referenced from module.v2 outputs
#
# IAM Permissions Boundary:
#   Managed by terraform/bootstrap
#
# Issue #86:
#   Fix SSM Bastion Security Group outbound rules
# ============================================================


# ------------------------------------------------------------
# 1. Local Variables
# ------------------------------------------------------------

locals {
  ssm_bastion_name = "needu-dev-ssm-bastion"

  ssm_bastion_vpc_id      = module.v2.vpc_id
  ssm_bastion_subnet_id   = module.v2.public_subnet_ids[0]
  ssm_bastion_mysql_sg    = module.v2.mysql_security_group_id
  ssm_bastion_postgres_sg = module.v2.postgres_security_group_id

  ssm_bastion_boundary_arn = "arn:aws:iam::919551759796:policy/NeedU-V2-dev-SSMBastionPermissionsBoundary"
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
# 3. EC2 Assume Role Policy
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
# 4. EC2 IAM Role
#
# Permissions Boundary is created by Bootstrap.
# Dev Terraform only references the existing policy.
# ------------------------------------------------------------

resource "aws_iam_role" "ssm_bastion" {
  name = local.ssm_bastion_name

  assume_role_policy = data.aws_iam_policy_document.ssm_bastion_assume.json

  permissions_boundary = local.ssm_bastion_boundary_arn

  tags = {
    Name = local.ssm_bastion_name
  }
}


# ------------------------------------------------------------
# 5. Attach SSM Managed Instance Policy
# ------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm_bastion" {
  role = aws_iam_role.ssm_bastion.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# ------------------------------------------------------------
# 6. IAM Instance Profile
# ------------------------------------------------------------

resource "aws_iam_instance_profile" "ssm_bastion" {
  name = local.ssm_bastion_name
  role = aws_iam_role.ssm_bastion.name
}


# ------------------------------------------------------------
# 7. Bastion Security Group
#
# Inbound:
#   No inbound rules
#
# Outbound:
#   TCP 443  -> AWS Systems Manager
#   TCP 3306 -> MySQL RDS
#   TCP 5432 -> PostgreSQL RDS
#
# Issue #86:
#   Do not manage ingress/egress inline.
#   Manage rules using dedicated rule resources only.
# ------------------------------------------------------------

resource "aws_security_group" "ssm_bastion" {
  name_prefix = "${local.ssm_bastion_name}-"

  description = "SSM Bastion for Dev RDS MySQL and PostgreSQL"
  vpc_id      = local.ssm_bastion_vpc_id

  # No inline ingress or egress blocks.
  # Rules are managed by aws_vpc_security_group_*_rule.

  tags = {
    Name = local.ssm_bastion_name
  }
}


# ------------------------------------------------------------
# 8. Bastion Outbound - HTTPS (443)
#
# Required for:
#   ssm.ap-northeast-2.amazonaws.com
#   ssmmessages.ap-northeast-2.amazonaws.com
#   ec2messages.ap-northeast-2.amazonaws.com
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
# 9. Bastion Outbound - MySQL (3306)
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
# 10. Bastion Outbound - PostgreSQL (5432)
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
# 11. MySQL RDS Inbound from Bastion
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
# 12. PostgreSQL RDS Inbound from Bastion
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
# 13. Bastion EC2
#
# t3.micro / Amazon Linux 2023
# Public Subnet / Public IP
# No SSH Key / No Inbound Port
# IMDSv2 Required
# Encrypted gp3 Root Volume
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
# 14. Outputs
# ------------------------------------------------------------

output "ssm_bastion_instance_id" {
  description = "SSM Bastion EC2 Instance ID"
  value       = aws_instance.ssm_bastion.id
}

output "ssm_bastion_security_group_id" {
  description = "SSM Bastion Security Group ID"
  value       = aws_security_group.ssm_bastion.id
}
