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

variable "centralized_logs_bucket" {
  description = "'Bucket' attribute for the Centralized Logs S3 bucket"
  type        = string
}

variable "ec2_isolation_dlq_arn" {
  description = "ARN of the EC2 Isolation function's DLQ"
  type        = string
}

variable "ec2_autostop_dlq_arn" {
  description = "ARN of the EC2 Autostop function's DLQ"
  type        = string
}

variable "ip_enrich_dlq_arn" {
  description = "ARN of the IP Enrichment function's DLQ"
}

variable "cloudtrail_log_delivery_arn" {
  description = "ARN of the CloudTrail Log Delivery SQS queue"
}

variable "cloudtrail_notifications_arn" {
  description = "ARN of the CloudTrail Notifications SNS topic"
}

variable "gen_purp_bucket_notifications_arn" {
  description = "ARN of the General Purpose bucket notifications SNS topic"
}