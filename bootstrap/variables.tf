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
