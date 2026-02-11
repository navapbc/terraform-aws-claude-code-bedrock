variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "developer_trusted_arns" {
  description = "List of IAM principal ARNs allowed to assume the developer role"
  type        = list(string)
}

variable "admin_trusted_arns" {
  description = "List of IAM principal ARNs allowed to assume the admin role"
  type        = list(string)
}

variable "allowed_model_arns" {
  description = "List of Bedrock model ARNs developers are permitted to invoke"
  type        = list(string)
}

variable "s3_bucket_prefix" {
  description = "Prefix for the S3 logging bucket (used in admin policy)"
  type        = string
}
