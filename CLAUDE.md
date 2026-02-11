# Claude Code Project Memory

Read `.claude/architecture.md` for full module details, resource flow, naming conventions, and known issues.

## Deployed Infrastructure

- **Region**: `us-east-1`
- **Model**: Claude Opus 4.6 (`us.anthropic.claude-opus-4-6-v1`)
- **41 resources** across 5 modules (foundation, allocation, logging, attribution, budgets)

### Inference Profiles (per-developer, with User tag)

One inference profile per developer, each tagged with `User` for cost attribution in AWS Cost Explorer. Profile ARNs are available via `terraform output inference_profile_arns`.

### IAM Roles

- Developer: `{project_name}-developer`
- Admin: `{project_name}-admin`
- Bedrock Logging: `{project_name}-bedrock-logging`

### Logging

- CloudWatch Log Group: `/aws/bedrock/{project_name}-invocations`
- S3 Invocation Logs: `{s3_bucket_prefix}-bedrock-invocation-logs` (encryption: AES256 / SSE-S3)
- S3 Athena Results: `{s3_bucket_prefix}-athena-results`

### Analytics

- Glue Database: `{project_name}_bedrock_logs`
- Athena Workgroup: `{project_name}-bedrock-logs`
- Athena queries group by `identity.arn` — only works when developers authenticate as their own IAM users (not via shared Bedrock API keys)

### Budgets

- Monthly budget and per-team budgets configurable via `monthly_budget_amount` and `team_budgets` variables
- SNS Topic: `{project_name}-budget-alerts`

## Key Gotchas

1. **Do NOT set `AWS_BEARER_TOKEN_BEDROCK`**: It overrides `AWS_PROFILE` and causes all requests to appear as a generic Bedrock API Key user, breaking per-developer attribution in logs.
2. **Streaming token counts are null**: Bedrock invocation logs do not populate `inputTokenCount`/`outputTokenCount` for `InvokeModelWithResponseStream` (which Claude Code uses). Athena can count invocations per developer but cannot compute dollar costs. Use AWS Cost Explorer with the `User` cost allocation tag for dollar attribution.
3. **Opus 4.6 model ARN has no `:0` suffix** and must use the cross-region inference profile ARN as source, not the foundation model ARN.
4. **S3 encryption is AES256 (SSE-S3)**, not KMS. KMS-encrypted objects cause Athena `AccessDenied on kms:Decrypt` errors.
5. **Developer config goes in `~/.claude/settings.json`**, not shell env vars in `~/.zshrc`.

## Outstanding Items

- Activate cost allocation tags (Team, Project, CostCenter, User) in AWS Billing console from the **management/payer account** (linked accounts do not have access)
- Confirm SNS subscription (check email for confirmation link)
- Avoid using Bedrock API Keys — they override IAM user identity in logs
- Eventually migrate developers from IAM user access keys to IAM role-based access
- Update Athena saved queries to focus on invocation counts (not dollar costs) since token counts are null for streaming, or remove dollar-cost queries to avoid confusion
