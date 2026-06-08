output "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state."
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  value       = aws_dynamodb_table.locks.name
}

output "app_backend_hcl" {
  description = "Backend configuration values for terraform/envs/dev/backend.hcl."
  value = {
    bucket         = aws_s3_bucket.state.bucket
    key            = "project-02/dev/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.locks.name
    encrypt        = true
  }
}
