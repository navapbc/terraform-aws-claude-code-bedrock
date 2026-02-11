# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email the maintainers directly. Include:

- A description of the vulnerability
- Steps to reproduce the issue
- Any potential impact
- Suggested fix (if you have one)

We will acknowledge receipt within 48 hours and provide a timeline for a fix.

## Scope

This project provides Terraform infrastructure-as-code for AWS. Security considerations include:

- **IAM policies**: Overly permissive roles or policies
- **S3 bucket configurations**: Public access, missing encryption
- **Logging gaps**: Missing audit trails or insufficient log retention
- **Budget bypass**: Ways to circumvent cost controls

## Best Practices for Users

When deploying this infrastructure:

- Use a **dedicated AWS account** within an Organization for isolation
- Apply the generated **SCP** to restrict the account's capabilities
- Enable **MFA** on all IAM users and roles
- Rotate access keys regularly; prefer IAM roles over long-lived credentials
- Do not commit `.tfvars` files, `tfplan` outputs, or state files to version control
- Do not set `AWS_BEARER_TOKEN_BEDROCK` — it breaks per-developer attribution
- Review IAM policies before applying to ensure they follow least-privilege principles
