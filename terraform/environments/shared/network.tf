resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "needu-v2-vpc"
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "needu-v2-igw"
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}
