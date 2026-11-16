provider "aws" {
  region = "ap-northeast-2"
}

# 기존 Bastion SG를 Shared Terraform에서 관리
resource "aws_security_group" "bastion" {
  name_prefix = "needu-dev-ssm-bastion-"

  description = "SSM Bastion for Dev RDS MySQL and PostgreSQL"
  vpc_id      = "vpc-0f2478c01e376b1b6"

  ingress = []

  lifecycle {
    prevent_destroy = true

    # State 이전 과정에서 기존 SG 규칙과 태그 보존
    ignore_changes = [
      egress,
      tags,
      tags_all
    ]
  }

  tags = {
    Name = "needu-dev-ssm-bastion"
  }
}

# 기존 Shared Bastion EC2 유지
resource "aws_instance" "bastion" {
  ami           = "ami-072184d2977237a82"
  instance_type = "t3.micro"

  subnet_id = "subnet-05ebd035963ad66d9"

  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]

  iam_instance_profile = "needu-ec2-role"

  associate_public_ip_address = true

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
    Name      = "needu-shared-ssm-bastion"
    Project   = "NeedU"
    ManagedBy = "Terraform"
    Purpose   = "SSM-RDS-PortForwarding"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}