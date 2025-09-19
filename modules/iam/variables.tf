variable "terraform_admin_username" {
  description = "IAM username of the Terraform admin user"
  type        = string
}

variable "account_id" {
  description = "The Terraform user's AWS account ID"
  type        = string
}

variable "general_purpose_bucket_arn" {
  description = "ARN of the General-Purpose S3 bucket"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  type        = string
}

variable "alerts_sns_topic_arn" {
  description = "ARN of the 'Alerts' SNS topic"
  type        = string
}