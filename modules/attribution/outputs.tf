output "sso_permission_set_arn" {
  description = "ARN of the SSO permission set for Claude Code developers"
  value       = var.enable_sso ? aws_ssoadmin_permission_set.developer[0].arn : null
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for querying invocation logs"
  value       = aws_athena_workgroup.bedrock_logs.name
}

output "athena_database_name" {
  description = "Name of the Athena database"
  value       = aws_athena_database.bedrock_logs.name
}

output "glue_table_name" {
  description = "Name of the Glue catalog table for invocation logs"
  value       = aws_glue_catalog_table.invocation_logs.name
}
