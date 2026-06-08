terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Owner       = var.owner
    Environment = "bootstrap"
    ManagedBy   = "terraform"
  }

  lock_table_name = coalesce(var.lock_table_name, "${var.project_name}-tf-locks")
}
