variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "backend_release_repo" {
  type        = string
  default     = "tango4giorgio/que-tanda-es-backend"
  description = "GitHub \"owner/repo\" whose tagged Releases publish the built Lambda package .zip assets (get_round.zip, gateway.zip, submit_feedback.zip)."
}

variable "backend_release_tag" {
  type        = string
  description = "Git tag of the backend release to deploy (e.g. \"v0.2.0\"). Must match a published release on backend_release_repo containing get_round.zip, gateway.zip, and submit_feedback.zip assets. Pinned explicitly (no default) so deployments are reproducible and reviewable."
}

variable "gateway_target_function_names" {
  type        = list(string)
  default     = ["tango-music-game-get-round", "tango-music-game-submit-feedback"]
  description = "Target Lambda function names the gateway's IAM role is permitted to invoke; must stay in sync with backend/src/gateway_config/routes.json."
}

variable "database_url_parameter_name" {
  type        = string
  default     = "/tango-music-game/catalogue/database-url"
  description = "SSM Parameter Store name (SecureString, free Standard tier) for the database URL."
}

variable "lambda_reserved_concurrency" {
  type        = number
  default     = 5
  description = "Maximum concurrent registry Lambda executions to protect Supabase connections."

  validation {
    condition     = var.lambda_reserved_concurrency >= 1 && var.lambda_reserved_concurrency <= 20
    error_message = "Lambda reserved concurrency must be between 1 and 20."
  }
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "CloudWatch log retention period."

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "Choose a supported CloudWatch Logs retention period."
  }
}

variable "supabase_access_token" {
  type        = string
  sensitive   = true
  description = "Supabase personal access token used by the Terraform provider."
}

variable "supabase_organization_id" {
  type        = string
  description = "Existing Supabase organisation slug from Organisation Settings."
}

variable "supabase_project_name" {
  type        = string
  default     = "tango-music-game"
  description = "Name of the Supabase project created for the catalogue backend."
}

variable "supabase_database_password" {
  type        = string
  sensitive   = true
  description = "Initial password for the Supabase Postgres database."

  validation {
    condition     = length(var.supabase_database_password) >= 12
    error_message = "The Supabase database password must contain at least 12 characters."
  }
}

variable "supabase_region" {
  type        = string
  default     = "eu-west-2"
  description = "Supabase region in which to create the project."
}

variable "supabase_instance_size" {
  type = string
  # "nano" is the free-tier compute class ($0/mo). "micro" and larger are paid
  # compute add-ons that require a Pro-plan organisation; do not change this
  # default without confirming the cost tradeoff.
  default     = "nano"
  description = "Supabase compute instance size."
}
