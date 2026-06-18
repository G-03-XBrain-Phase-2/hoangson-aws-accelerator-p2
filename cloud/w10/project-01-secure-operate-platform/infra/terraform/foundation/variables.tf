variable "aws_region" {
  description = "AWS region used for W10 foundation resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "ecr_repository_name" {
  description = "Private ECR repository for the W10 application image."
  type        = string
  default     = "w10-api"
}

variable "github_org" {
  description = "GitHub organization or username that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI role."
  type        = string
}

variable "github_branch" {
  description = "Git branch allowed to assume the CI role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set to false if the AWS account already has one and import/use an existing provider instead."
  type        = bool
  default     = true
}
