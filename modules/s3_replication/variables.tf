variable "random_suffix_hex" {
  description = "The hexxed value of the 'random_id.random_suffix' resource"
  type        = string
}

variable "secondary_aws_region" {
  description = "The AWS region for backup resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  type        = string
}

variable "replication_role_arn" {
  description = "ARN of the S3 replicas' IAM role"
  type        = string
}

variable "centralized_logs_replica_bucket_arn" {
  description = "ARN of the Centralized Logs Replica S3 bucket"
  type        = string
}