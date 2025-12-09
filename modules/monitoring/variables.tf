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