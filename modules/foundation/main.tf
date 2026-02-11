################################################################################
# ClaudeCodeDeveloper IAM Role
################################################################################

data "aws_iam_policy_document" "developer_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.developer_trusted_arns
    }
  }
}

resource "aws_iam_role" "developer" {
  name               = "${var.project_name}-developer"
  assume_role_policy = data.aws_iam_policy_document.developer_assume_role.json

  tags = {
    Role = "ClaudeCodeDeveloper"
  }
}

data "aws_iam_policy_document" "developer_permissions" {
  statement {
    sid    = "AllowBedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = var.allowed_model_arns
  }

  # Allow invoking through Application Inference Profiles
  statement {
    sid    = "AllowInferenceProfileInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = ["arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/*"]
  }

  statement {
    sid    = "AllowGetInferenceProfile"
    effect = "Allow"
    actions = [
      "bedrock:GetInferenceProfile",
      "bedrock:ListInferenceProfiles",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "developer" {
  name   = "${var.project_name}-developer-policy"
  role   = aws_iam_role.developer.id
  policy = data.aws_iam_policy_document.developer_permissions.json
}

################################################################################
# ClaudeCodeAdmin IAM Role
################################################################################

data "aws_iam_policy_document" "admin_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.admin_trusted_arns
    }
  }
}

resource "aws_iam_role" "admin" {
  name               = "${var.project_name}-admin"
  assume_role_policy = data.aws_iam_policy_document.admin_assume_role.json

  tags = {
    Role = "ClaudeCodeAdmin"
  }
}

data "aws_iam_policy_document" "admin_permissions" {
  # Full Bedrock access
  statement {
    sid       = "AllowBedrockFull"
    effect    = "Allow"
    actions   = ["bedrock:*"]
    resources = ["*"]
  }

  # CloudWatch read/write for logs and metrics
  statement {
    sid    = "AllowCloudWatch"
    effect = "Allow"
    actions = [
      "logs:*",
      "cloudwatch:*",
    ]
    resources = ["*"]
  }

  # S3 access for invocation logs
  statement {
    sid    = "AllowS3Logs"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_prefix}-bedrock-invocation-logs",
      "arn:aws:s3:::${var.s3_bucket_prefix}-bedrock-invocation-logs/*",
    ]
  }

  # S3 access for Athena query results
  statement {
    sid    = "AllowS3AthenaResults"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_prefix}-athena-results",
      "arn:aws:s3:::${var.s3_bucket_prefix}-athena-results/*",
    ]
  }

  # Cost Explorer read access
  statement {
    sid    = "AllowCostExplorer"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostForecast",
      "ce:GetTags",
    ]
    resources = ["*"]
  }

  # Athena query access
  statement {
    sid    = "AllowAthena"
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:ListNamedQueries",
      "athena:GetNamedQuery",
    ]
    resources = ["*"]
  }

  # Glue catalog access for Athena
  statement {
    sid    = "AllowGlue"
    effect = "Allow"
    actions = [
      "glue:GetTable",
      "glue:GetDatabase",
      "glue:GetPartitions",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "admin" {
  name   = "${var.project_name}-admin-policy"
  role   = aws_iam_role.admin.id
  policy = data.aws_iam_policy_document.admin_permissions.json
}

################################################################################
# SCP Policy Document (for manual application in management account)
################################################################################

data "aws_iam_policy_document" "scp" {
  # Allow only Bedrock and supporting services
  statement {
    sid    = "AllowBedrockAndSupporting"
    effect = "Allow"
    actions = [
      "bedrock:*",
      "logs:*",
      "cloudwatch:*",
      "s3:*",
      "iam:*",
      "sts:*",
      "sns:*",
      "budgets:*",
      "ce:*",
      "athena:*",
      "glue:*",
      "sso:*",
      "kms:*",
    ]
    resources = ["*"]
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
