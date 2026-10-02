variable "supabase_access_token" {
  type        = string
  sensitive   = true
  description = "Supabase personal access token used only to create or import the application project."
}

variable "supabase_organization_id" {
  type        = string
  description = "Existing Supabase organisation slug from Organisation Settings."
}

variable "supabase_project_name" {
  type        = string
  default     = "tango-music-game"
  description = "Name of the Supabase project created for the application database."
}

variable "supabase_database_password" {
  type        = string
  sensitive   = true
  description = "Initial password for the Supabase Postgres superuser."

  validation {
    condition     = length(var.supabase_database_password) >= 12
    error_message = "The Supabase database password must contain at least 12 characters."
  }
}

variable "supabase_region" {
  type        = string
  default     = "eu-west-2"
  description = "Supabase region in which to create the application project."
}
