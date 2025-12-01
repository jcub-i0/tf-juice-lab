variable "lambda_ec2_isolate_exec_role_arn" {
  description = "ARN of the Lambda EC2 Isolation function's execution role"
  type = string
}

variable "lambda_ip_enrich_arn" {
 description = "ARN of the Lambda IP Enrichment function"
 type = string 
}

variable "environment" {
  description = "Deployment environment"
  type = string
}

variable "replication_role_arn" {
  description = "ARN of the replica S3 bucket IAM policy"
  type = string
}