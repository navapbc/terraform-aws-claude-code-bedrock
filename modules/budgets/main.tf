################################################################################
# SNS Topic for Alerts
################################################################################

resource "aws_sns_topic" "budget_alerts" {
  name = "${var.project_name}-budget-alerts"

  tags = {
    Purpose = "bedrock-cost-alerting"
  }
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn = aws_sns_topic.budget_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowCloudWatchAlarmsPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.budget_alert_emails)

  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

################################################################################
# Overall Bedrock Monthly Budget
################################################################################

resource "aws_budgets_budget" "bedrock_monthly" {
  name         = "${var.project_name}-bedrock-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }
}

################################################################################
# Per-Team Budgets (optional)
################################################################################

resource "aws_budgets_budget" "team" {
  for_each = var.enable_team_budgets ? var.team_budgets : {}

  name         = "${var.project_name}-team-${each.key}"
  budget_type  = "COST"
  limit_amount = tostring(each.value.amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Bedrock"]
  }

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:CostCenter$${each.value.cost_center}"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }
}

################################################################################
# CloudWatch Metric Filters (token usage from invocation logs)
################################################################################

resource "aws_cloudwatch_log_metric_filter" "input_tokens" {
  name           = "${var.project_name}-input-tokens"
  log_group_name = var.log_group_name
  pattern        = "{ $.inputTokenCount > 0 }"

  metric_transformation {
    name          = "InputTokenCount"
    namespace     = "ClaudeCode/Bedrock"
    value         = "$.inputTokenCount"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "output_tokens" {
  name           = "${var.project_name}-output-tokens"
  log_group_name = var.log_group_name
  pattern        = "{ $.outputTokenCount > 0 }"

  metric_transformation {
    name          = "OutputTokenCount"
    namespace     = "ClaudeCode/Bedrock"
    value         = "$.outputTokenCount"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "invocation_count" {
  name           = "${var.project_name}-invocation-count"
  log_group_name = var.log_group_name
  pattern        = "{ $.requestId = \"*\" }"

  metric_transformation {
    name          = "InvocationCount"
    namespace     = "ClaudeCode/Bedrock"
    value         = "1"
    default_value = "0"
  }
}

################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "high_invocation_rate" {
  alarm_name          = "${var.project_name}-high-invocation-rate"
  alarm_description   = "Alert when Bedrock invocation rate exceeds 500 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InvocationCount"
  namespace           = "ClaudeCode/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 500
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.budget_alerts.arn]
  ok_actions    = [aws_sns_topic.budget_alerts.arn]

  tags = {
    Purpose = "cost-anomaly-detection"
  }
}

resource "aws_cloudwatch_metric_alarm" "output_token_spike" {
  alarm_name          = "${var.project_name}-output-token-spike"
  alarm_description   = "Alert when output tokens exceed 2M in 1 hour"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "OutputTokenCount"
  namespace           = "ClaudeCode/Bedrock"
  period              = 3600
  statistic           = "Sum"
  threshold           = 2000000
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.budget_alerts.arn]
  ok_actions    = [aws_sns_topic.budget_alerts.arn]

  tags = {
    Purpose = "cost-anomaly-detection"
  }
}

resource "aws_cloudwatch_metric_alarm" "throttle_rate" {
  alarm_name          = "${var.project_name}-throttle-rate"
  alarm_description   = "Alert when Bedrock throttling exceeds 10 in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "InvocationThrottles"
  namespace           = "AWS/Bedrock"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.budget_alerts.arn]
  ok_actions    = [aws_sns_topic.budget_alerts.arn]

  tags = {
    Purpose = "cost-anomaly-detection"
  }
}

################################################################################
# Bedrock Guardrails (optional)
################################################################################

resource "aws_bedrock_guardrail" "this" {
  count = var.enable_guardrails ? 1 : 0

  name                      = "${var.project_name}-guardrail"
  description               = "Content safety guardrail for Claude Code usage"
  blocked_input_messaging   = "Your request was blocked by organizational policy."
  blocked_outputs_messaging = "The response was blocked by organizational policy."

  dynamic "topic_policy_config" {
    for_each = length(var.guardrail_blocked_topics) > 0 ? [1] : []

    content {
      dynamic "topics_config" {
        for_each = var.guardrail_blocked_topics

        content {
          name       = topics_config.value
          definition = "Block requests related to ${topics_config.value}"
          type       = "DENY"
        }
      }
    }
  }

  tags = {
    Purpose = "content-safety"
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
