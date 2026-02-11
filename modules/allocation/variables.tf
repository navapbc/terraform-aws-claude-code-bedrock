variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
}

variable "inference_profiles" {
  description = "Map of team/project inference profiles to create"
  type = map(object({
    model_arn   = string
    description = optional(string, "")
    team_tag    = string
    project_tag = string
    cost_center = string
    user_tag    = optional(string, "")
  }))
  default = {}
}
