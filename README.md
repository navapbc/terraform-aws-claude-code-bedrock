# Claude Code + Amazon Bedrock: Infrastructure & Cost Monitoring

Terraform project that provisions AWS infrastructure for running [Claude Code](https://claude.ai/code) with Amazon Bedrock, including comprehensive cost tracking, per-developer attribution, and budget controls.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Dedicated AWS Account                        │
│                                                                 │
│  ┌──────────┐    ┌──────────────────┐    ┌──────────────────┐  │
│  │ IAM Roles│    │  Bedrock Models  │    │   Inference      │  │
│  │ Dev/Admin│───▶│ Claude Opus 4.6  │◀───│   Profiles       │  │
│  └──────────┘    └────────┬─────────┘    │ (per-developer)  │  │
│                           │              └──────────────────┘  │
│                    Invocation Logs                              │
│                           │                                    │
│              ┌────────────┼────────────┐                       │
│              ▼                         ▼                       │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │  CloudWatch Logs │    │    S3 Bucket     │                  │
│  │  (real-time)     │    │  (long-term)     │                  │
│  └────────┬─────────┘    └────────┬─────────┘                  │
│           │                       │                            │
│           ▼                       ▼                            │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │ Metric Filters   │    │ Glue + Athena    │                  │
│  │ & Alarms         │    │ (per-dev queries)│                  │
│  └────────┬─────────┘    └──────────────────┘                  │
│           │                                                    │
│           ▼                                                    │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │   SNS Alerts     │    │  AWS Budgets     │                  │
│  │ (Slack/PagerDuty)│    │ (50/80/100%)     │                  │
│  └──────────────────┘    └──────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

| Layer | Module | AWS Services | Granularity |
|-------|--------|-------------|-------------|
| Foundation | `foundation` | IAM, STS | Account-level |
| Logging | `logging` | CloudWatch Logs, S3, Bedrock Logging | Per-invocation |
| Allocation | `allocation` | Bedrock Inference Profiles, Cost Explorer | Per-developer |
| Attribution | `attribution` | IAM Identity Center, Athena, Glue | Per-developer |
| Budgets | `budgets` | AWS Budgets, SNS, CloudWatch Alarms | Configurable |

## Prerequisites

- AWS account within an AWS Organization
- Terraform >= 1.5.0
- AWS CLI v2 with credentials for the target account
- (Optional) S3 backend bucket and DynamoDB table for remote state
- (Optional) Corporate IdP (Okta, Azure AD, etc.) for SSO integration

## Quick Start

1. Clone this repository:
   ```bash
   git clone <repo-url>
   cd claude-code-bedrock
   ```

2. Complete the manual prerequisites in [MANUAL_STEPS.md](MANUAL_STEPS.md) (Phase 1 section).

3. Create your variables file:
   ```bash
   cp environments/prod.tfvars.example environments/prod.tfvars
   ```

4. Edit `environments/prod.tfvars` with your account-specific values.

5. (Optional) Configure remote state by uncommenting `backend.tf`.

6. Deploy:
   ```bash
   terraform init
   terraform plan -var-file=environments/prod.tfvars
   terraform apply -var-file=environments/prod.tfvars
   ```

7. Complete post-apply manual steps in [MANUAL_STEPS.md](MANUAL_STEPS.md).

## Modules

### `foundation`
IAM roles (`ClaudeCodeDeveloper`, `ClaudeCodeAdmin`) and an SCP policy document for restricting the account to Bedrock and supporting services.

### `logging`
Bedrock model invocation logging to CloudWatch Logs and S3. Includes saved Logs Insights queries for ad-hoc cost analysis (daily usage by caller, hourly totals, top consumers, model breakdown).

### `allocation`
Per-developer Application Inference Profiles with cost allocation tags (`Team`, `Project`, `CostCenter`, `User`). After tag activation, filtered cost data appears in AWS Cost Explorer.

### `attribution`
IAM Identity Center (SSO) permission set for per-developer identity in logs. Athena workgroup, Glue catalog table, and named queries for per-developer cost breakdowns.

### `budgets`
AWS Budgets (overall + per-team), SNS alerting, CloudWatch metric filters and alarms for anomaly detection (high invocation rate, token spikes, throttling). Optional Bedrock Guardrails.

## Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `us-east-1` | AWS region |
| `project_name` | string | `claude-code` | Prefix for resource names |
| `developer_trusted_arns` | list(string) | — | ARNs allowed to assume the developer role |
| `admin_trusted_arns` | list(string) | — | ARNs allowed to assume the admin role |
| `allowed_model_arns` | list(string) | Opus 4.6 | Bedrock model ARNs developers can invoke |
| `s3_bucket_prefix` | string | — | Globally unique prefix for S3 buckets |
| `log_retention_days` | number | `30` | CloudWatch log retention |
| `s3_lifecycle_expiration_days` | number | `365` | S3 log expiration |
| `inference_profiles` | map(object) | `{}` | Team/project inference profiles |
| `enable_sso` | bool | `false` | Create SSO permission set |
| `monthly_budget_amount` | number | `1000` | Monthly Bedrock budget (USD) |
| `budget_alert_emails` | list(string) | `[]` | Alert notification emails |
| `enable_team_budgets` | bool | `false` | Create per-team budgets |
| `enable_guardrails` | bool | `false` | Create Bedrock Guardrails |

See `variables.tf` for the full list with descriptions.

## Developer Onboarding

After deployment, get the developer configuration:

```bash
terraform output developer_env_config
terraform output inference_profile_arns
```

Each developer creates `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1",
    "ANTHROPIC_MODEL": "us.anthropic.claude-opus-4-6-v1",
    "AWS_PROFILE": "claude-code"
  }
}
```

For per-developer cost allocation via inference profiles, add the profile ARN:

```json
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1",
    "ANTHROPIC_MODEL": "us.anthropic.claude-opus-4-6-v1",
    "AWS_PROFILE": "claude-code",
    "CLAUDE_CODE_BEDROCK_PROFILE_ARN": "<profile-arn-from-terraform-output>"
  }
}
```

> **Warning**: Do NOT set `AWS_BEARER_TOKEN_BEDROCK` in your environment. This variable is not used by Claude Code and will cause authentication failures with Bedrock.

### SSO Authentication (Optional)

If your organization uses SSO via IAM Identity Center (e.g., Azure AD / Microsoft Entra ID), developers authenticate with their corporate identity instead of IAM access keys. This automatically provides per-developer attribution in Bedrock invocation logs.

Set up the AWS CLI SSO profile:

```bash
aws configure sso
```

This creates a named profile in `~/.aws/config`:

```ini
[profile claude-code]
sso_session = claude-code
sso_account_id = 123456789012
sso_role_name = claude-code-developer
region = us-east-1

[sso-session claude-code]
sso_start_url = https://d-1234567890.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access
```

Then reference this profile in `~/.claude/settings.json` as `AWS_PROFILE` and authenticate before using Claude Code:

```bash
aws sso login --profile claude-code
```

See [MANUAL_STEPS.md](MANUAL_STEPS.md) (Phase 4) for full SSO setup instructions, including Azure AD / Entra ID configuration.

## Querying Cost Data

**CloudWatch Logs Insights** — Saved queries are created automatically. Open the CloudWatch console, go to Logs Insights, and select from the saved queries prefixed with your project name.

**Athena** — Named queries are available in the Athena console under the project workgroup:
- Per-developer weekly cost
- Per-developer monthly cost
- Daily cost trend

**Cost Explorer** — After cost allocation tags activate (~24 hours), filter by `Team`, `Project`, or `CostCenter` tags.

## Cost Optimization

- **Prompt caching**: Bedrock caches repeated context. Monitor `cacheReadInputTokenCount` in logs.
- **Batch inference**: Use for non-interactive workloads (code review pipelines, bulk docs) at ~50% lower cost.
- **Intelligent prompt routing**: Route simple requests to lighter models automatically.
- **Model selection**: Choose the right model for each use case:

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| Claude Haiku 3.5 | $0.80 | $4.00 |
| Claude Sonnet 4 | $3.00 | $15.00 |
| Claude Sonnet 4.5 | $3.00 | $15.00 |
| Claude Opus 4 | $15.00 | $75.00 |
| Claude Opus 4.6 | $15.00 | $75.00 |

## Manual Steps

Some actions cannot be automated via Terraform. See [MANUAL_STEPS.md](MANUAL_STEPS.md) for the full checklist including:
- AWS account creation and Bedrock model access
- SCP application in the management account
- Cost allocation tag activation
- IdP configuration and SSO user assignment
- SNS email subscription confirmations

## License

MIT
