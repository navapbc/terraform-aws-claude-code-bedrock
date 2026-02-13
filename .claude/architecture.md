# Architecture Reference

## Overview

Terraform project provisioning AWS infrastructure for Claude Code on Amazon Bedrock. Five-module phased architecture: IAM foundation, invocation logging, per-developer cost allocation via inference profiles, per-developer attribution via SSO + Athena, and budget controls with alerting.

## Module Dependency Graph

```
main.tf (root)
  |
  ├── modules/foundation   (Phase 1) - No dependencies
  │     → IAM roles, SCP policy document
  │
  ├── modules/logging      (Phase 2) - No dependencies
  │     → CloudWatch Log Group, S3 bucket, Bedrock logging config, Insights queries
  │
  ├── modules/allocation   (Phase 3) - No dependencies
  │     → Bedrock Inference Profiles (per-developer)
  │
  ├── modules/attribution  (Phase 4) - Depends on: logging (s3_bucket_name)
  │     → SSO permission set, Athena workgroup, Glue table, named queries
  │
  └── modules/budgets      (Phase 5) - Depends on: logging (log_group_name)
        → AWS Budgets, SNS, CloudWatch metric filters + alarms, Guardrails
```

## Key Resource Flow

```
Developer (IAM Role / SSO) → Bedrock InvokeModel (via Inference Profile)
    ↓ invocation logs
CloudWatch Logs ──→ Metric Filters ──→ CloudWatch Alarms ──→ SNS Topic ──→ Email/Slack
    ↓                                                              ↑
S3 Bucket (long-term) ──→ Glue Table ──→ Athena Queries      AWS Budgets ─┘
```

## File Map

| File | Purpose |
|------|---------|
| `main.tf` | Root module orchestration — wires all 5 modules |
| `variables.tf` | All root-level input variables (165 lines) |
| `outputs.tf` | Root outputs including `developer_env_config` convenience output |
| `providers.tf` | AWS provider with `default_tags` from `var.tags` |
| `versions.tf` | Terraform >= 1.5.0, AWS provider ~> 5.0 |
| `backend.tf` | Remote state template (commented out) |
| `environments/prod.tfvars.example` | Full example configuration |

## Module Details

### foundation (`modules/foundation/`)
- **Resources**: 2 IAM roles (developer, admin), inline policies, SCP data source
- **Key behavior**: Developer role scoped to `bedrock:InvokeModel` + `InvokeModelWithResponseStream` on allowed model ARNs + inference profiles. Admin gets `bedrock:*`, `logs:*`, `cloudwatch:*`, S3 read on logs bucket, `ce:*`, `athena:*`, `glue:*`.
- **SCP**: Output as JSON for manual application in Organizations management account. Allowlist pattern (must remove default `FullAWSAccess` SCP to take effect).

### logging (`modules/logging/`)
- **Resources**: CloudWatch Log Group, S3 bucket (versioned, AES256 / SSE-S3 encrypted, public access blocked), lifecycle rules, bucket policy for Bedrock service, `aws_bedrock_model_invocation_logging_configuration`, 4 saved Insights queries
- **Key behavior**: Account-level Bedrock logging config — logs to CloudWatch for real-time and S3 for long-term. S3 transitions to IA after configurable days, expires after configurable days.

### allocation (`modules/allocation/`)
- **Resources**: `aws_bedrock_inference_profile` (one per entry in `var.inference_profiles`)
- **Key behavior**: Each profile gets `Team`, `Project`, `CostCenter` tags for Cost Explorer filtering. Optional `User` tag for per-developer cost tracking. Developers set `CLAUDE_CODE_BEDROCK_PROFILE_ARN` to route through their personal profile.
- **Per-user tracking**: Create one profile per developer with `user_tag` set. After activating the `User` cost allocation tag in AWS Billing (~24h), per-user costs appear in Cost Explorer.
- **Default model**: Opus 4.6 (`anthropic.claude-opus-4-6-v1`)

### attribution (`modules/attribution/`)
- **Resources**: Optional SSO permission set + inline policy, Athena results S3 bucket (AES256 / SSE-S3 encrypted, 30-day expiration), Athena workgroup (SSE_S3 results encryption), Athena database, Glue catalog table, 3 named queries
- **Key behavior**: Glue table maps S3 invocation logs as external table with JSON SerDe. Athena queries calculate estimated costs using configurable token prices. SSO gated by `var.enable_sso`.
- **Glue schema columns**: timestamp, requestid, modelid, inputtokencount, outputtokencount, cachereadinputtokencount, cachewriteinputtokencount, identity (struct with arn)

### budgets (`modules/budgets/`)
- **Resources**: SNS topic + email subscriptions, overall monthly budget (50/80/100% thresholds + 80% forecasted), optional per-team budgets (80/100% thresholds), 3 CloudWatch metric filters, 3 CloudWatch alarms, optional Bedrock Guardrail
- **Key behavior**: Metric filters extract token counts from CloudWatch Logs into `ClaudeCode/Bedrock` custom namespace. Alarms: >500 invocations/5min, >2M output tokens/hour, >10 throttles/5min. Per-team budgets filter by `CostCenter` tag.

## Variable Flow

Root `variables.tf` → `main.tf` passes subsets to each module. Key pass-throughs:
- `project_name` → all modules (naming prefix)
- `aws_region` → foundation, attribution
- `s3_bucket_prefix` → foundation (admin policy), logging (bucket name), attribution (fallback for athena bucket)
- `allowed_model_arns` → foundation (developer policy), attribution (SSO policy)
- `module.logging.s3_bucket_name` → attribution (Glue table location)
- `module.logging.log_group_name` → budgets (metric filters)

## Naming Conventions

- IAM roles: `{project_name}-developer`, `{project_name}-admin`
- S3 buckets: `{s3_bucket_prefix}-bedrock-invocation-logs`, `{s3_bucket_prefix}-athena-results`
- Log groups: `/aws/bedrock/{project_name}-invocations`
- Inference profiles: `{project_name}-{profile_key}`
- SNS: `{project_name}-budget-alerts`
- Budgets: `{project_name}-bedrock-monthly`, `{project_name}-team-{key}`
- Alarms: `{project_name}-high-invocation-rate`, `{project_name}-output-token-spike`, `{project_name}-throttle-rate`
- Athena: database `{project_name}_bedrock_logs` (hyphens → underscores), workgroup `{project_name}-bedrock-logs`

## Common Operations

```bash
# Deploy
terraform init
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars

# Inspect outputs
terraform output developer_env_config
terraform output inference_profile_arns
terraform output -raw scp_policy_json

# Format & validate
terraform fmt -recursive
terraform validate
```

## Known Issues / Tech Debt

1. No validation when `enable_sso = true` but `sso_instance_arn` is empty
2. Cost queries assume Opus 4.6 pricing for all Claude models
3. Cost queries don't account for cached token pricing
4. Guardrail topic definitions are auto-generated (not configurable per topic)
5. `developer_env_config` output hardcodes model name
6. Token counts (`InputTokenCount`, `OutputTokenCount`) are null for `InvokeModelWithResponseStream` — streaming invocations only log invocation count, not token usage. Cost estimation from CloudWatch metrics will undercount when streaming is used (which is the default for Claude Code).
7. Per-developer cost queries in Athena require the `User` cost allocation tag to be activated in AWS Billing (~24h delay)
