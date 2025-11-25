variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "random_suffix_hex" {
  description = "Random hex value"
  type = string
}

variable "replication_role_arn" {
  description = "ARN of the Replication IAM Role"
  type = string
}

