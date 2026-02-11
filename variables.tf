################################################################################
# General
################################################################################

variable "aws_region" {
  description = "AWS region for Bedrock and supporting resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
  default     = "claude-code"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Foundation
################################################################################

variable "developer_trusted_arns" {
  description = "List of IAM principal ARNs allowed to assume the ClaudeCodeDeveloper role (federated IdP ARNs, IAM user ARNs, etc.)"
  type        = list(string)
}

variable "admin_trusted_arns" {
  description = "List of IAM principal ARNs allowed to assume the ClaudeCodeAdmin role"
  type        = list(string)
}

variable "allowed_model_arns" {
  description = "List of Bedrock model ARNs developers are permitted to invoke"
  type        = list(string)
  default = [
    "arn:aws:bedrock:*::foundation-model/anthropic.claude-opus-4-6-v1",
  ]
}

################################################################################
# Logging
################################################################################

variable "s3_bucket_prefix" {
  description = "Globally unique prefix for the S3 logging bucket (e.g. your org name)"
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

################################################################################
# Allocation (Inference Profiles)
################################################################################

variable "inference_profiles" {
  description = "Map of team/project inference profiles to create. Each profile gets cost allocation tags."
  type = map(object({
    model_arn   = string
    description = optional(string, "")
    team_tag    = string
    project_tag = string
    cost_center = string
    user_tag    = optional(string, "")
  }))
  default = {}
}

################################################################################
# Attribution (SSO + Athena)
################################################################################

variable "enable_sso" {
  description = "Whether to create IAM Identity Center (SSO) permission set"
  type        = bool
  default     = false
}

variable "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance (required if enable_sso = true)"
  type        = string
  default     = ""
}

variable "athena_query_result_bucket_prefix" {
  description = "Prefix for the Athena query results S3 bucket"
  type        = string
  default     = ""
}

variable "input_price_per_m" {
  description = "Price per 1M input tokens for cost estimation in Athena queries"
  type        = number
  default     = 15.0
}

variable "output_price_per_m" {
  description = "Price per 1M output tokens for cost estimation in Athena queries"
  type        = number
  default     = 75.0
}

################################################################################
# Budgets & Alerting
################################################################################

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD for Bedrock spend"
  type        = number
  default     = 1000
}

variable "budget_alert_emails" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = []
}

variable "enable_team_budgets" {
  description = "Whether to create per-team budgets based on inference profiles"
  type        = bool
  default     = false
}

variable "team_budgets" {
  description = "Per-team budget configuration (used when enable_team_budgets = true)"
  type = map(object({
    amount      = number
    cost_center = string
  }))
  default = {}
}

variable "enable_guardrails" {
  description = "Whether to create Bedrock Guardrails for content safety"
  type        = bool
  default     = false
}

variable "guardrail_blocked_topics" {
  description = "List of topic names to block via Bedrock Guardrails"
  type        = list(string)
  default     = []
}
