variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
}

variable "s3_bucket_prefix" {
  description = "Globally unique prefix for the S3 logging bucket"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}

variable "s3_lifecycle_expiration_days" {
  description = "Number of days before S3 log objects expire"
  type        = number
  default     = 365
}

variable "s3_lifecycle_ia_transition_days" {
  description = "Number of days before S3 log objects transition to Infrequent Access"
  type        = number
  default     = 90
}
