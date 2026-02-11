# Contributing

Thank you for your interest in contributing to this project. We welcome contributions from the community.

## How to Contribute

1. **Fork** the repository
2. **Create a branch** for your feature or fix (`git checkout -b feature/my-change`)
3. **Make your changes** and ensure they follow the existing code conventions
4. **Test** your changes with `terraform validate` and `terraform plan`
5. **Commit** with a clear, descriptive message
6. **Open a pull request** against `main`

## Development Setup

- Terraform >= 1.5.0
- AWS CLI v2
- An AWS account with Bedrock access (for testing)

## Code Conventions

- All resources use `var.project_name` as a naming prefix
- S3 buckets use `var.s3_bucket_prefix` for global uniqueness
- Tags are applied via `provider.aws.default_tags`
- Athena database names replace hyphens with underscores
- Run `terraform fmt -recursive` before committing

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include your Terraform version, AWS provider version, and relevant error output
- Do not include AWS account IDs, ARNs, or credentials in issue reports

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
