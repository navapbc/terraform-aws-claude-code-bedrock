# Manual Steps

These actions cannot be automated via Terraform and must be completed manually in the AWS Console or via your IdP.

## Phase 1: Foundation (Pre-Apply)

Complete these **before** running `terraform apply`.

- [ ] **Create a dedicated AWS account** in AWS Organizations (e.g., `claude-code-prod`). This provides a clean billing boundary.
- [ ] **Enable Amazon Bedrock** in the target region(s) — `us-east-1`, `us-west-2`, or `eu-west-1`.
- [ ] **Request model access** for Claude Opus 4.6 (or your desired Claude model) in the Bedrock console under **Model access**.
- [ ] **Apply the SCP** to the dedicated account from the management account. After `terraform apply`, the SCP JSON is available via:
  ```bash
  terraform output -raw scp_policy_json
  ```
  Create a new SCP in the Organizations console and attach it to the Claude Code account OU.

## Phase 3: Cost Allocation Tags (Post-Apply)

Complete these **after** running `terraform apply`.

- [ ] **Activate cost allocation tags** in the AWS Billing console:
  1. Go to **Billing** → **Cost allocation tags**
  2. Search for the tags: `Team`, `Project`, `CostCenter`, `User`
  3. Select them and click **Activate**
  4. Tags take ~24 hours to appear in Cost Explorer

## Phase 4: Attribution (Post-Apply)

Complete these if using SSO for per-developer attribution.

- [ ] **Configure your corporate IdP** (Okta, Azure AD, Google Workspace) with AWS IAM Identity Center. Follow your IdP's documentation for the SAML/SCIM integration.
- [ ] **Assign users/groups** to the SSO permission set in IAM Identity Center:
  1. Go to **IAM Identity Center** → **AWS accounts**
  2. Select the Claude Code account
  3. Assign the `claude-code-developer` permission set to the appropriate groups
- [ ] **Validate the Glue table schema** against live Bedrock invocation log data. After some invocations have been logged:
  1. Go to the Athena console
  2. Select the `claude_code_bedrock_logs` workgroup
  3. Run `SELECT * FROM invocation_logs LIMIT 10`
  4. Verify all columns are populated correctly

## Phase 5: Budget Alerts (Post-Apply)

- [ ] **Confirm SNS email subscriptions.** Each email address in `budget_alert_emails` will receive a confirmation email from AWS. Click the confirmation link in each.
- [ ] **Configure Slack/PagerDuty integration** (optional). Create a subscription on the SNS topic using the HTTPS protocol pointing to your Slack webhook or PagerDuty Events API endpoint.

## Developer Onboarding

Each developer must configure their Claude Code CLI. After `terraform apply`, get the configuration:

```bash
terraform output developer_env_config
terraform output inference_profile_arns
```

Developers should create `~/.claude/settings.json` with their Bedrock configuration:

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

For per-developer cost allocation via inference profiles, add the profile ARN from the Terraform output:

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

If using SSO, authenticate via:

```bash
aws sso login --profile claude-code
```
