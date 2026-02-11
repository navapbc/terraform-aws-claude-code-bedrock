################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "bedrock_invocations" {
  name              = "/aws/bedrock/${var.project_name}-invocations"
  retention_in_days = var.log_retention_days

  tags = {
    Purpose = "bedrock-invocation-logging"
  }
}

################################################################################
# S3 Bucket for Invocation Logs
################################################################################

resource "aws_s3_bucket" "invocation_logs" {
  bucket = "${var.s3_bucket_prefix}-bedrock-invocation-logs"

  tags = {
    Purpose = "bedrock-invocation-logging"
  }
}

resource "aws_s3_bucket_versioning" "invocation_logs" {
  bucket = aws_s3_bucket.invocation_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "invocation_logs" {
  bucket = aws_s3_bucket.invocation_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "invocation_logs" {
  bucket = aws_s3_bucket.invocation_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "invocation_logs" {
  bucket = aws_s3_bucket.invocation_logs.id

  rule {
    id     = "log-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = var.s3_lifecycle_ia_transition_days
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.s3_lifecycle_expiration_days
    }
  }
}

resource "aws_s3_bucket_policy" "invocation_logs" {
  bucket = aws_s3_bucket.invocation_logs.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "AllowBedrockLogging"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.invocation_logs.arn}/${var.project_name}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

################################################################################
# IAM Role for Bedrock CloudWatch Logging
################################################################################

resource "aws_iam_role" "bedrock_logging" {
  name = "${var.project_name}-bedrock-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "bedrock_logging" {
  name = "cloudwatch-logs"
  role = aws_iam_role.bedrock_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.bedrock_invocations.arn}:*"
      }
    ]
  })
}

################################################################################
# Bedrock Model Invocation Logging Configuration
################################################################################

resource "aws_bedrock_model_invocation_logging_configuration" "this" {
  logging_config {
    embedding_data_delivery_enabled = false

    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock_invocations.name
      role_arn       = aws_iam_role.bedrock_logging.arn

      large_data_delivery_s3_config {
        bucket_name = aws_s3_bucket.invocation_logs.id
        key_prefix  = var.project_name
      }
    }

    s3_config {
      bucket_name = aws_s3_bucket.invocation_logs.id
      key_prefix  = var.project_name
    }
  }
}

################################################################################
# CloudWatch Logs Insights Saved Queries
################################################################################

resource "aws_cloudwatch_query_definition" "daily_usage_by_caller" {
  name = "${var.project_name}/daily-token-usage-by-caller"

  log_group_names = [aws_cloudwatch_log_group.bedrock_invocations.name]

  query_string = <<-EOQ
    fields @timestamp, identity.arn, inputTokenCount, outputTokenCount
    | stats sum(inputTokenCount) as totalInput,
            sum(outputTokenCount) as totalOutput
      by identity.arn, bin(1d)
    | sort totalOutput desc
  EOQ
}

resource "aws_cloudwatch_query_definition" "hourly_token_totals" {
  name = "${var.project_name}/hourly-token-totals"

  log_group_names = [aws_cloudwatch_log_group.bedrock_invocations.name]

  query_string = <<-EOQ
    fields @timestamp, inputTokenCount, outputTokenCount
    | stats sum(inputTokenCount) as totalInput,
            sum(outputTokenCount) as totalOutput
      by bin(1h)
    | sort @timestamp desc
  EOQ
}

resource "aws_cloudwatch_query_definition" "top_consumers_last_7d" {
  name = "${var.project_name}/top-consumers-last-7d"

  log_group_names = [aws_cloudwatch_log_group.bedrock_invocations.name]

  query_string = <<-EOQ
    fields identity.arn, inputTokenCount, outputTokenCount
    | stats sum(inputTokenCount) as totalInput,
            sum(outputTokenCount) as totalOutput,
            count(*) as invocations
      by identity.arn
    | sort totalOutput desc
    | limit 20
  EOQ
}

resource "aws_cloudwatch_query_definition" "model_usage_breakdown" {
  name = "${var.project_name}/model-usage-breakdown"

  log_group_names = [aws_cloudwatch_log_group.bedrock_invocations.name]

  query_string = <<-EOQ
    fields modelId, inputTokenCount, outputTokenCount
    | stats sum(inputTokenCount) as totalInput,
            sum(outputTokenCount) as totalOutput,
            count(*) as invocations
      by modelId
    | sort totalOutput desc
  EOQ
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
