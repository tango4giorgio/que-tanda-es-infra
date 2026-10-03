terraform {
  required_version = "~> 1.16.0"

  backend "pg" {}

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
  }
}
