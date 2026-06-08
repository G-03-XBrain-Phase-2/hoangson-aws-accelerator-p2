variable "aws_region" {
  type        = string
  description = "AWS region for backend resources."
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
  default     = "student"
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name."
  }
}

variable "lock_table_name" {
  type        = string
  description = "DynamoDB table name for Terraform state locking. Defaults to <project_name>-tf-locks."
  default     = null
}
