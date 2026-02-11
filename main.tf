################################################################################
# Phase 1: Foundation — IAM Roles & SCP Policy
################################################################################

module "foundation" {
  source = "./modules/foundation"

  project_name           = var.project_name
  aws_region             = var.aws_region
  developer_trusted_arns = var.developer_trusted_arns
  admin_trusted_arns     = var.admin_trusted_arns
  allowed_model_arns     = var.allowed_model_arns
  s3_bucket_prefix       = var.s3_bucket_prefix
}

################################################################################
# Phase 2: Logging — CloudWatch, S3, Bedrock Invocation Logging
################################################################################

module "logging" {
  source = "./modules/logging"

  project_name                    = var.project_name
  s3_bucket_prefix                = var.s3_bucket_prefix
  log_retention_days              = var.log_retention_days
  s3_lifecycle_expiration_days    = var.s3_lifecycle_expiration_days
  s3_lifecycle_ia_transition_days = var.s3_lifecycle_ia_transition_days
}

################################################################################
# Phase 3: Allocation — Application Inference Profiles
################################################################################

module "allocation" {
  source = "./modules/allocation"

  project_name       = var.project_name
  inference_profiles = var.inference_profiles
}

################################################################################
# Phase 4: Attribution — SSO, Athena, Glue
################################################################################

module "attribution" {
  source = "./modules/attribution"

  project_name                      = var.project_name
  aws_region                        = var.aws_region
  enable_sso                        = var.enable_sso
  sso_instance_arn                  = var.sso_instance_arn
  allowed_model_arns                = var.allowed_model_arns
  s3_invocation_logs_bucket         = module.logging.s3_bucket_name
  athena_query_result_bucket_prefix = var.athena_query_result_bucket_prefix != "" ? var.athena_query_result_bucket_prefix : var.s3_bucket_prefix
  input_price_per_m                 = var.input_price_per_m
  output_price_per_m                = var.output_price_per_m
}

################################################################################
# Phase 5: Budget Controls & Alerting
################################################################################

module "budgets" {
  source = "./modules/budgets"

  project_name             = var.project_name
  log_group_name           = module.logging.log_group_name
  monthly_budget_amount    = var.monthly_budget_amount
  budget_alert_emails      = var.budget_alert_emails
  enable_team_budgets      = var.enable_team_budgets
  team_budgets             = var.team_budgets
  enable_guardrails        = var.enable_guardrails
  guardrail_blocked_topics = var.guardrail_blocked_topics
}
