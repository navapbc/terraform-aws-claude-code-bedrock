output "inference_profile_arns" {
  description = "Map of profile name to inference profile ARN"
  value       = { for k, v in aws_bedrock_inference_profile.this : k => v.arn }
}

output "inference_profile_ids" {
  description = "Map of profile name to inference profile ID"
  value       = { for k, v in aws_bedrock_inference_profile.this : k => v.id }
}
