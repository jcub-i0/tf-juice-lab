variable "aws_region" {
  description = "The primary AWS Region that the cloud environment uses"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "alert_emails" {
  description = "Email address to send CloudWatch Alarm alerts to"
  type        = list(string)
}

variable "guardduty_features" {
  description = "List of features to be added to GuardDuty - Determines data souces"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the main KMS key"
  type        = string
}

variable "vpc_flow_logs_arn" {
  description = "ARN of the VPC Flow Logs resource"
  type        = string
}

variable "vpc_id" {
  description = "ID attribute of the main VPC"
  type        = string
}

variable "config_role_arn" {
  description = "ARN of the AWS Config IAM role"
  type        = string
}

variable "config_remediation_role_arn" {
  description = "ARN of the AWS Config Remediation IAM role"
  type        = string
}

variable "cloudtrail_sns_to_sqs_json" {
  description = "JSON attribute of the policy that allows CloudTrail SNS topic to publish to SQS"
  type        = string
}

variable "config_delivery_channel" {
  description = "References the config_delivery_channel resource"
  type        = any
}

variable "config_ssm_automation_policy_attachment" {
  description = "Config SSM Automation policy attachment resource"
  type        = any
}