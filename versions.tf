terraform {
  required_version = "~> 1.16.0"

  backend "pg" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.4"
    }
  }
}
