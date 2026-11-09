terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.24"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "needu"
      Version     = "v3"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
