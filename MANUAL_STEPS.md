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

> **Note**: Phase 2 (logging) is fully automated by Terraform — no manual steps required. CloudWatch Log Group, S3 bucket, and Bedrock logging configuration are all provisioned during `terraform apply`.

## Phase 3: Cost Allocation Tags (Post-Apply)

Complete these **after** running `terraform apply`.

- [ ] **Activate cost allocation tags** in the AWS Billing console:
  1. Go to **Billing** → **Cost allocation tags**
  2. Search for the tags: `Team`, `Project`, `CostCenter`, `User`
  3. Select them and click **Activate**
  4. Tags take ~24 hours to appear in Cost Explorer

## Phase 4: Attribution — SSO Setup (Post-Apply)

Complete these if using SSO for per-developer attribution. SSO gives each developer a unique federated identity in Bedrock invocation logs, enabling per-developer cost tracking without relying solely on inference profiles.

Set `enable_sso = true` and provide your `sso_instance_arn` in your `.tfvars` before running `terraform apply` for these resources to be created.

### Option A: Azure AD / Microsoft Entra ID (Recommended)

This is the preferred IdP for organizations using Active Directory.

- [ ] **Enable IAM Identity Center** in the AWS Organizations management account:
  1. Go to **IAM Identity Center** in the AWS Console
  2. Choose **Enable** (must be done from the management account)
  3. Select your preferred region (should match your Bedrock deployment)

- [ ] **Connect Azure AD as the external identity source**:
  1. In IAM Identity Center, go to **Settings** → **Identity source** → **Actions** → **Change identity source**
  2. Select **External identity provider**
  3. Download the **IAM Identity Center SAML metadata file**
  4. In the Azure portal, go to **Microsoft Entra ID** → **Enterprise applications** → **New application**
  5. Search for **AWS IAM Identity Center** and add it
  6. Under **Single sign-on**, select **SAML** and upload the metadata file from step 3
  7. Copy the **Azure AD SAML metadata URL** back into IAM Identity Center to complete the trust

- [ ] **Enable SCIM provisioning** (automatic user/group sync):
  1. In IAM Identity Center **Settings**, go to **Automatic provisioning** → **Enable**
  2. Copy the **SCIM endpoint** and **Access token**
  3. In the Azure portal, go to the AWS IAM Identity Center enterprise app → **Provisioning**
  4. Set mode to **Automatic**, paste the SCIM endpoint as **Tenant URL** and access token as **Secret Token**
  5. Click **Test Connection**, then **Save**
  6. Under **Mappings**, ensure user and group mappings are configured
  7. Start provisioning — users and groups will sync within minutes

- [ ] **Create a security group in Azure AD** for Claude Code developers:
  1. In the Azure portal, go to **Microsoft Entra ID** → **Groups** → **New group**
  2. Name it `Claude Code Developers` (or similar)
  3. Add the developers who should have Bedrock access

- [ ] **Assign the group to the SSO permission set**:
  1. In IAM Identity Center, go to **AWS accounts**
  2. Select the Claude Code account
  3. Click **Assign users or groups**
  4. Select the `Claude Code Developers` group (synced from Azure AD)
  5. Assign the `claude-code-developer` permission set

### Option B: Other Identity Providers

For **Okta**, **Google Workspace**, or other SAML/SCIM providers, the process is similar:
1. Enable IAM Identity Center and configure the external IdP (SAML + SCIM)
2. Create a group for Claude Code developers in your IdP
3. Assign the group to the `claude-code-developer` permission set

See the [AWS IAM Identity Center documentation](https://docs.aws.amazon.com/singlesignon/latest/userguide/supported-idps.html) for provider-specific guides.

### Configure Developer AWS CLI Profiles

After SSO is configured, each developer runs:

```bash
aws configure sso
```

Use these values when prompted:
- **SSO session name**: `claude-code`
- **SSO start URL**: your IAM Identity Center start URL (e.g., `https://d-1234567890.awsapps.com/start`)
- **SSO region**: your IAM Identity Center region (e.g., `us-east-1`)
- **SSO registration scopes**: `sso:account:access`

This creates a profile in `~/.aws/config`. Example:

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

### Validate

- [ ] **Test SSO login**:
  ```bash
  aws sso login --profile claude-code
  aws sts get-caller-identity --profile claude-code
  ```
  Verify the ARN shows your federated identity (not a generic IAM user).

- [ ] **Validate the Glue table schema** against live Bedrock invocation log data. After some invocations have been logged:
  1. Go to the Athena console
  2. Select the `claude_code_bedrock_logs` workgroup
  3. Run `SELECT * FROM invocation_logs LIMIT 10`
  4. Verify `identity.arn` contains the developer's federated ARN

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
