################################################################################
# Application Inference Profiles
################################################################################

resource "aws_bedrock_inference_profile" "this" {
  for_each = var.inference_profiles

  name        = "${var.project_name}-${each.key}"
  description = each.value.description != "" ? each.value.description : "Inference profile for ${each.key}"

  model_source {
    copy_from = each.value.model_arn
  }

  tags = merge(
    {
      Team       = each.value.team_tag
      Project    = each.value.project_tag
      CostCenter = each.value.cost_center
    },
    each.value.user_tag != "" ? { User = each.value.user_tag } : {}
  )
}
