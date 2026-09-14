variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "lambda_package_path" {
  type    = string
  default = "../backend/dist/get_catalogue.zip"
}

variable "database_url_secret_name" {
  type    = string
  default = "tango-music-game/catalogue/database-url"
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
  type        = string
  default     = "micro"
  description = "Supabase compute instance size."
}
