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
  type        = string
}

variable "centralized_logs_replica_bucket_arn" {
  description = "ARN of the Centralized Logs Replica S3 bucket"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key"
  type        = string
}