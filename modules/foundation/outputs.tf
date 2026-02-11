output "developer_role_arn" {
  description = "ARN of the ClaudeCodeDeveloper IAM role"
  value       = aws_iam_role.developer.arn
}

output "developer_role_name" {
  description = "Name of the ClaudeCodeDeveloper IAM role"
  value       = aws_iam_role.developer.name
}

output "admin_role_arn" {
  description = "ARN of the ClaudeCodeAdmin IAM role"
  value       = aws_iam_role.admin.arn
}

output "admin_role_name" {
  description = "Name of the ClaudeCodeAdmin IAM role"
  value       = aws_iam_role.admin.name
}

output "scp_policy_json" {
  description = "SCP policy document JSON to apply in the management account"
  value       = data.aws_iam_policy_document.scp.json
}
