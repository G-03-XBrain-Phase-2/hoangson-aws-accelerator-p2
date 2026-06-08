variable "aws_region" {
  type        = string
  description = "AWS region for the application stack."
  default     = "ap-southeast-1"
}

variable "project_name" {
  type        = string
  description = "Project name prefix."
  default     = "demo-web-app"
}

variable "owner" {
  type        = string
  description = "Owner tag value."
  default     = "nguyen-hoang-son"
}

variable "environment" {
  type        = string
  description = "Environment name."
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.50.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets."
  default     = ["10.50.1.0/24", "10.50.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets."
  default     = ["10.50.11.0/24", "10.50.12.0/24"]
}

variable "web_ingress_cidr" {
  type        = string
  description = "CIDR allowed to access the web server on HTTP port 80."
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.web_ingress_cidr, 0))
    error_message = "web_ingress_cidr must be a valid CIDR block, for example 171.225.184.193/32."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the web server."
  default     = "t3.micro"
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS volume size in GiB."
  default     = 30

  validation {
    condition     = var.root_volume_size >= 30
    error_message = "root_volume_size must be at least 30 GiB for the selected Amazon Linux 2023 AMI."
  }
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "RDS allocated storage in GiB."
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage must be at least 20 GiB for RDS MySQL."
  }
}

variable "db_name" {
  type        = string
  description = "Initial MySQL database name."
  default     = "appdb"
}

variable "db_username" {
  type        = string
  description = "RDS master username."
  default     = "appadmin"
}

variable "db_backup_retention_period" {
  type        = number
  description = "RDS backup retention in days."
  default     = 1

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "db_backup_retention_period must be between 0 and 35 days."
  }
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Whether to skip the final snapshot on RDS destroy. Use false for production."
  default     = true
}

variable "db_deletion_protection" {
  type        = bool
  description = "Enable RDS deletion protection. Use true for production."
  default     = false
}

variable "assets_bucket_name" {
  type        = string
  description = "Optional custom S3 bucket name for static assets. Must be globally unique."
  default     = null

  validation {
    condition     = var.assets_bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.assets_bucket_name))
    error_message = "assets_bucket_name must be null or a valid lowercase S3 bucket name."
  }
}
