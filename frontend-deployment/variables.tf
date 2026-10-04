variable "frontend_release_tag" {
  type        = string
  description = "Immutable frontend release tag represented by the prebuilt files."

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+([.-][0-9A-Za-z.-]+)?$", var.frontend_release_tag))
    error_message = "The frontend release tag must be a semantic version beginning with v."
  }
}

variable "backend_gateway_url" {
  type        = string
  description = "Terraform-managed backend gateway URL used for the same-origin /api rewrite."

  validation {
    condition     = can(regex("^https://[^/]+(/.*)?$", var.backend_gateway_url))
    error_message = "The backend gateway URL must use HTTPS."
  }
}

variable "vercel_team_id" {
  type        = string
  description = "Vercel team or account identifier."
}

variable "vercel_project_id" {
  type        = string
  description = "Existing Vercel project identifier receiving production deployments."
}
