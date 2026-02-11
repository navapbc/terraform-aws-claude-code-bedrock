output "log_group_name" {
  description = "Name of the CloudWatch log group for Bedrock invocations"
  value       = aws_cloudwatch_log_group.bedrock_invocations.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.bedrock_invocations.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for invocation logs"
  value       = aws_s3_bucket.invocation_logs.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for invocation logs"
  value       = aws_s3_bucket.invocation_logs.arn
}
