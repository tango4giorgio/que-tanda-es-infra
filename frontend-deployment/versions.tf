terraform {
  required_version = "~> 1.16.0"

  backend "pg" {}

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.6"
    }
    vercel = {
      source  = "vercel/vercel"
      version = "~> 5.19"
    }
  }
}
