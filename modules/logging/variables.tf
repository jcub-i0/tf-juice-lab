variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "random_suffix_hex" {
  description = "Random hex value"
  type        = string
}

variable "replication_role_arn" {
  description = "ARN of the Replication IAM Role"
  type        = string
}

variable "kms_master_key_arn" {
  description = "ARN of the KMS master key"
  type        = string
}

variable "centralized_logs_replica_bucket" {
  description = "Centralized Logs Replica S3 bucket"
  type        = any
}

variable "centralized_logs_replica_bucket_arn" {
  description = "ARN of the Centralized Logs Replica S3 bucket"
  type        = string
}

variable "centralized_logs_replica_bucket_s3_bucket_arn" {
  description = "NOT the same as centralized_logs_replica_bucket_arn -- This is an output from public S3 module"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key"
  type        = string
}

variable "kms_replica_secondary_region_key_arn" {
  description = "ARN of the KMS Replica Key based in the secondary region"
  type        = string
}

variable "centralized_logs_topic_policy" {
  description = "Centralized Logs Topic Policy"
  type        = any
}

variable "config_configuration_recorder_config_rec" {
  description = "Configuration Recorder"
  type        = any
}

variable "cloudtrail_to_cw_role" {
  description = "Reference to the aws_iam_role.cloudtrail_to_cw_role resource"
  type        = any
}

variable "cloudtrail_to_cw_role_arn" {
  description = "ARN of the aws_iam_role.cloudtrail_to_cw_role resouce"
  type        = string
}

variable "cloudtrail_to_cw_policy" {
  description = "Reference to the aws_iam_role_policy.cloudtrail_to_cw_policy resource"
  type        = any
}

variable "cloudtrail_logs" {
  description = "Reference to the aws_cloudwatch_log_group.cloudtrail_logs resource"
  type        = any
}

variable "cloudtrail_logs_arn" {
  description = "ARN of the aws_cloudwatch_log_group.cloudtrail_logs resource"
  type        = string
}

variable "cloudtrail_notifications_name" {
  description = "'name' attribute of the aws_sns_topic.cloudtrail_notifications resource"
  type        = string
}