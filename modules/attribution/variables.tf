variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "enable_sso" {
  description = "Whether to create IAM Identity Center (SSO) permission set"
  type        = bool
  default     = false
}

variable "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  type        = string
  default     = ""
}

variable "allowed_model_arns" {
  description = "List of Bedrock model ARNs for the SSO permission set"
  type        = list(string)
  default     = []
}

variable "s3_invocation_logs_bucket" {
  description = "Name of the S3 bucket containing Bedrock invocation logs"
  type        = string
}

variable "athena_query_result_bucket_prefix" {
  description = "Prefix for the Athena query results S3 bucket"
  type        = string
}

variable "input_price_per_m" {
  description = "Price per 1M input tokens for cost estimation"
  type        = number
  default     = 15.0
}

variable "output_price_per_m" {
  description = "Price per 1M output tokens for cost estimation"
  type        = number
  default     = 75.0
}
