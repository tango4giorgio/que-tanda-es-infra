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

variable "github_environment" {
  type        = string
  default     = "production"
  description = "GitHub environment whose workflows may assume the deployment role."
}

variable "terraform_state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for the main configuration's Terraform state."
}

variable "terraform_lock_table_name" {
  type        = string
  default     = "tango-music-game-terraform-locks"
  description = "DynamoDB table used to lock the main configuration's Terraform state."
}
