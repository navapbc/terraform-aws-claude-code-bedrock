variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group for Bedrock invocations"
  type        = string
}

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
  description = "Whether to create per-team budgets"
  type        = bool
  default     = false
}

variable "team_budgets" {
  description = "Per-team budget configuration"
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
