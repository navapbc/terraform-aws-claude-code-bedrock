output "sns_topic_arn" {
  description = "ARN of the SNS topic for budget and alarm notifications"
  value       = aws_sns_topic.budget_alerts.arn
}

output "budget_name" {
  description = "Name of the overall Bedrock monthly budget"
  value       = aws_budgets_budget.bedrock_monthly.name
}

output "guardrail_id" {
  description = "ID of the Bedrock Guardrail (null if not enabled)"
  value       = var.enable_guardrails ? aws_bedrock_guardrail.this[0].guardrail_id : null
}
