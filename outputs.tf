################################################################################
# Foundation
################################################################################

output "developer_role_arn" {
  description = "ARN of the ClaudeCodeDeveloper IAM role"
  value       = module.foundation.developer_role_arn
}

output "admin_role_arn" {
  description = "ARN of the ClaudeCodeAdmin IAM role"
  value       = module.foundation.admin_role_arn
}

output "scp_policy_json" {
  description = "SCP policy JSON — apply this in your management account"
  value       = module.foundation.scp_policy_json
}

################################################################################
# Logging
################################################################################

output "log_group_name" {
  description = "CloudWatch log group for Bedrock invocations"
  value       = module.logging.log_group_name
}

output "invocation_logs_bucket" {
  description = "S3 bucket for Bedrock invocation logs"
  value       = module.logging.s3_bucket_name
}

################################################################################
# Allocation
################################################################################

output "inference_profile_arns" {
  description = "Map of team name to inference profile ARN"
  value       = module.allocation.inference_profile_arns
}

################################################################################
# Attribution
################################################################################

output "sso_permission_set_arn" {
  description = "SSO permission set ARN for Claude Code developers"
  value       = module.attribution.sso_permission_set_arn
}

output "athena_workgroup" {
  description = "Athena workgroup for querying invocation logs"
  value       = module.attribution.athena_workgroup_name
}

output "athena_database" {
  description = "Athena database name"
  value       = module.attribution.athena_database_name
}

################################################################################
# Budgets
################################################################################

output "sns_topic_arn" {
  description = "SNS topic for budget and alarm notifications"
  value       = module.budgets.sns_topic_arn
}

output "guardrail_id" {
  description = "Bedrock Guardrail ID (null if not enabled)"
  value       = module.budgets.guardrail_id
}

################################################################################
# Developer Onboarding — Environment Variables
################################################################################

output "developer_env_config" {
  description = "Environment variables for developer Claude Code CLI configuration"
  value = {
    CLAUDE_CODE_USE_BEDROCK = "1"
    AWS_REGION              = var.aws_region
    ANTHROPIC_MODEL         = "global.anthropic.claude-opus-4-6-v1"
    note                    = "Set AWS_PROFILE to a named profile that assumes the developer role: ${module.foundation.developer_role_arn}"
  }
}
