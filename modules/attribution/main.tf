################################################################################
# IAM Identity Center (SSO) Permission Set
################################################################################

resource "aws_ssoadmin_permission_set" "developer" {
  count = var.enable_sso ? 1 : 0

  name             = "${var.project_name}-developer"
  description      = "Permission set for Claude Code developers via Bedrock"
  instance_arn     = var.sso_instance_arn
  session_duration = "PT8H"

  tags = {
    Purpose = "claude-code-developer-access"
  }
}

# To programmatically assign an Azure AD / Entra ID group to the permission set,
# uncomment the resource below. You'll need the group's principal ID from IAM
# Identity Center (synced from your IdP via SCIM).
#
# resource "aws_ssoadmin_account_assignment" "developer_group" {
#   count = var.enable_sso ? 1 : 0
#
#   instance_arn       = var.sso_instance_arn
#   permission_set_arn = aws_ssoadmin_permission_set.developer[0].arn
#
#   principal_id   = "YOUR_GROUP_PRINCIPAL_ID"  # From IAM Identity Center → Groups
#   principal_type = "GROUP"
#
#   target_id   = data.aws_caller_identity.current.account_id
#   target_type = "AWS_ACCOUNT"
# }

resource "aws_ssoadmin_permission_set_inline_policy" "developer" {
  count = var.enable_sso ? 1 : 0

  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer[0].arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = var.allowed_model_arns
      },
      {
        Sid    = "AllowInferenceProfileInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/*"
      },
      {
        Sid    = "AllowListProfiles"
        Effect = "Allow"
        Action = [
          "bedrock:GetInferenceProfile",
          "bedrock:ListInferenceProfiles",
        ]
        Resource = "*"
      },
    ]
  })
}

################################################################################
# Athena Workgroup & Database
################################################################################

resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.athena_query_result_bucket_prefix}-athena-results"

  tags = {
    Purpose = "athena-query-results"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

resource "aws_athena_workgroup" "bedrock_logs" {
  name = "${var.project_name}-bedrock-logs"

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = {
    Purpose = "bedrock-cost-analysis"
  }
}

resource "aws_athena_database" "bedrock_logs" {
  name   = replace("${var.project_name}_bedrock_logs", "-", "_")
  bucket = aws_s3_bucket.athena_results.id
}

################################################################################
# Glue Catalog Table (Bedrock Invocation Logs Schema)
################################################################################

resource "aws_glue_catalog_table" "invocation_logs" {
  name          = "invocation_logs"
  database_name = aws_athena_database.bedrock_logs.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification"     = "json"
    "typeOfData"         = "file"
    "EXTERNAL"           = "TRUE"
    "has_encrypted_data" = "true"
  }

  storage_descriptor {
    location      = "s3://${var.s3_invocation_logs_bucket}/${var.project_name}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "paths" = "identity,inputTokenCount,modelId,outputTokenCount,requestId,timestamp"
      }
    }

    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "requestid"
      type = "string"
    }
    columns {
      name = "modelid"
      type = "string"
    }
    columns {
      name = "inputtokencount"
      type = "bigint"
    }
    columns {
      name = "outputtokencount"
      type = "bigint"
    }
    columns {
      name = "cachereadinputtokencount"
      type = "bigint"
    }
    columns {
      name = "cachewriteinputtokencount"
      type = "bigint"
    }
    columns {
      name = "identity"
      type = "struct<arn:string>"
    }
  }
}

################################################################################
# Athena Named Queries
################################################################################

resource "aws_athena_named_query" "per_developer_weekly_cost" {
  name      = "${var.project_name}-per-developer-weekly-cost"
  workgroup = aws_athena_workgroup.bedrock_logs.name
  database  = aws_athena_database.bedrock_logs.name

  query = <<-EOQ
    SELECT
      identity.arn AS developer,
      date_trunc('week', from_iso8601_timestamp(timestamp)) AS week,
      SUM(inputtokencount) AS input_tokens,
      SUM(outputtokencount) AS output_tokens,
      ROUND(SUM(inputtokencount) * ${var.input_price_per_m} / 1000000
          + SUM(outputtokencount) * ${var.output_price_per_m} / 1000000, 2) AS est_cost_usd
    FROM invocation_logs
    WHERE modelid LIKE '%claude%'
    GROUP BY 1, 2
    ORDER BY est_cost_usd DESC
  EOQ
}

resource "aws_athena_named_query" "per_developer_monthly_cost" {
  name      = "${var.project_name}-per-developer-monthly-cost"
  workgroup = aws_athena_workgroup.bedrock_logs.name
  database  = aws_athena_database.bedrock_logs.name

  query = <<-EOQ
    SELECT
      identity.arn AS developer,
      date_trunc('month', from_iso8601_timestamp(timestamp)) AS month,
      SUM(inputtokencount) AS input_tokens,
      SUM(outputtokencount) AS output_tokens,
      ROUND(SUM(inputtokencount) * ${var.input_price_per_m} / 1000000
          + SUM(outputtokencount) * ${var.output_price_per_m} / 1000000, 2) AS est_cost_usd
    FROM invocation_logs
    WHERE modelid LIKE '%claude%'
    GROUP BY 1, 2
    ORDER BY est_cost_usd DESC
  EOQ
}

resource "aws_athena_named_query" "daily_cost_trend" {
  name      = "${var.project_name}-daily-cost-trend"
  workgroup = aws_athena_workgroup.bedrock_logs.name
  database  = aws_athena_database.bedrock_logs.name

  query = <<-EOQ
    SELECT
      date_trunc('day', from_iso8601_timestamp(timestamp)) AS day,
      COUNT(*) AS invocations,
      SUM(inputtokencount) AS input_tokens,
      SUM(outputtokencount) AS output_tokens,
      ROUND(SUM(inputtokencount) * ${var.input_price_per_m} / 1000000
          + SUM(outputtokencount) * ${var.output_price_per_m} / 1000000, 2) AS est_cost_usd
    FROM invocation_logs
    WHERE modelid LIKE '%claude%'
    GROUP BY 1
    ORDER BY day DESC
  EOQ
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
