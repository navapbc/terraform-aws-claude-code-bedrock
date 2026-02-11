# AGENTS.md

This file provides guidance to AI coding assistants (such as Claude Code) when working with code in this repository.

## Project Overview

Terraform project that provisions AWS infrastructure for running Claude Code with Amazon Bedrock. Includes per-developer cost attribution, team-based allocation via inference profiles, and budget controls with alerting.

## Commands

```bash
# Initialize Terraform (required before first plan/apply)
terraform init

# Validate configuration syntax
terraform validate

# Format Terraform files
terraform fmt -recursive

# Preview changes (always use the var-file)
terraform plan -var-file=environments/prod.tfvars

# Apply changes
terraform apply -var-file=environments/prod.tfvars

# View specific outputs
terraform output developer_env_config
terraform output inference_profile_arns
terraform output -raw scp_policy_json
```

## Architecture

The project is organized into five Terraform modules, deployed in phases:

**Phase 1: `modules/foundation/`**
- IAM roles: `ClaudeCodeDeveloper` (Bedrock invoke only) and `ClaudeCodeAdmin` (full Bedrock + logs + Cost Explorer)
- SCP policy document (must be manually applied in AWS Organizations management account)
- Restricts developer model access to ARNs specified in `allowed_model_arns`

**Phase 2: `modules/logging/`**
- CloudWatch Log Group for real-time Bedrock invocation logs
- S3 bucket for long-term log storage with lifecycle rules (IA transition → expiration)
- `aws_bedrock_model_invocation_logging_configuration` resource enables logging at account level
- Pre-built CloudWatch Logs Insights saved queries for daily/hourly usage analysis

**Phase 3: `modules/allocation/`**
- Application Inference Profiles with per-developer `User` tag (`aws_bedrock_inference_profile`)
- Cost allocation tags: `Team`, `Project`, `CostCenter`, `User` (must be activated manually in AWS Billing)

**Phase 4: `modules/attribution/`**
- Optional SSO permission set for per-developer identity in logs
- Athena workgroup + Glue catalog table for querying S3 invocation logs
- Pre-built named queries for per-developer weekly/monthly cost breakdowns

**Phase 5: `modules/budgets/`**
- AWS Budgets with 50/80/100% threshold alerts
- SNS topic for notifications (supports email, Slack webhook, PagerDuty)
- CloudWatch metric filters extracting `InputTokenCount`, `OutputTokenCount`, `InvocationCount` from logs (note: token counts are null for `InvokeModelWithResponseStream` — streaming invocations only log invocation count)
- CloudWatch alarms for anomaly detection (high invocation rate, token spikes, throttling)
- Optional Bedrock Guardrails for content safety

## Key Variables

Configuration is passed via `.tfvars` files in `environments/`. Required variables:
- `developer_trusted_arns` / `admin_trusted_arns`: IAM principals allowed to assume roles
- `s3_bucket_prefix`: Globally unique prefix for S3 buckets (org name recommended)
- `budget_alert_emails`: Addresses to receive SNS notifications

## Manual Steps

Some actions cannot be automated via Terraform. See `MANUAL_STEPS.md` for:
- Pre-apply: AWS account creation, Bedrock model access requests, SCP application
- Post-apply: Cost allocation tag activation (24h delay), SNS email confirmations, SSO/IdP integration

## Conventions

- All resources use `var.project_name` prefix (default: `claude-code`)
- S3 buckets use `var.s3_bucket_prefix` for global uniqueness
- Tags are applied via `provider.aws.default_tags` from `var.tags`
- Athena database names replace hyphens with underscores for compatibility
