variable "aws_region" {
  type        = string
  default     = "eu-west-2"
  description = "Must match the aws_region used by the main backend-infra configuration, since IAM resource ARNs below are region-scoped."
}

variable "resource_name_prefix" {
  type        = string
  default     = "tango-music-game"
  description = "Must match the resource name prefix used by the main backend-infra configuration (Lambda function/role names, log group names, SSM parameter path). Changing this here without changing it there will make the deployer user unable to manage the real resources."
}

variable "deployer_user_name" {
  type        = string
  default     = "tango-music-game-deployer"
  description = "IAM user name created for running the main backend-infra Terraform configuration."
}

variable "github_repository" {
  type        = string
  default     = "tango4giorgio/que-tanda-es-infra"
  description = "GitHub owner/repository allowed to assume the deployment role."
}

variable "github_repository_owner_id" {
  type        = string
  default     = "328818540"
  description = "Immutable GitHub owner ID used in OIDC subject claims for repositories created after 15 July 2026."

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_owner_id))
    error_message = "github_repository_owner_id must contain only digits."
  }
}

variable "github_repository_id" {
  type        = string
  default     = "1370526941"
  description = "Immutable GitHub repository ID used in OIDC subject claims for repositories created after 15 July 2026."

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must contain only digits."
  }
}

variable "github_environment" {
  type        = string
  default     = "production"
  description = "GitHub environment whose workflows may assume the deployment role."
}

variable "supabase_access_token" {
  type        = string
  sensitive   = true
  description = "Supabase personal access token used by the Terraform provider to create the dedicated Terraform-state project."
}

variable "supabase_organization_id" {
  type        = string
  description = "Existing Supabase organisation slug (Organisation Settings -> General -> Slug) that will own the Terraform-state project. Must already exist; Terraform cannot create organisations."
}

variable "tfstate_project_name" {
  type        = string
  default     = "tango-music-game-tfstate"
  description = "Name of the dedicated Supabase project created solely to hold the Terraform state Storage bucket. Kept separate from the application project so state exists before the application project is created."
}

variable "supabase_region" {
  type        = string
  default     = "eu-west-2"
  description = "Supabase region for the Terraform-state project. Does not need to match the main configuration's supabase_region, but keeping them aligned avoids unnecessary cross-region latency."
}
