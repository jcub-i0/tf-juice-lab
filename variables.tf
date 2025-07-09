variable "terraform_admin_username" {
  description = "IAM username of the Terraform admin user"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_sub_cidr" {
  description = "CIDR address for the Public Subnet"
  type        = string
  default     = "10.0.1.0/28"
}

variable "public_sub_az" {
  description = "Availability Zone for the Public Subnet"
  type        = string
  default     = "us-east-1a"
}

variable "private_sub_cidr" {
  description = "CIDR address for the Private Subnet"
  type        = string
  default     = "10.0.0.0/28"
}

variable "private_sub_az" {
  description = "Availability Zone for the Private Subnet"
  type        = string
  default     = "us-east-1a"
}

variable "bastion_allowed_cidrs" {
  description = "The CIDR(s) of the local machine(s) allowed to access the Bastion Host instance"
  type        = list(string)
}

variable "alert_emails" {
  description = "Email address to send CloudWatch Alarm alerts to"
  type        = list(string)
}

variable "guardduty_features" {
  description = "List of features to be added to GuardDuty - Determines data souces"
  type        = list(string)
  default = [
    "S3_DATA_EVENTS",
    "EBS_MALWARE_PROTECTION",
    "LAMBDA_NETWORK_LOGS",
    "RUNTIME_MONITORING"
  ]
}


variable "idle_cpu_threshold" {
  description = "The CPU percentage that's indicative of an idle EC2 instance"
  type        = string
  default     = "5"
}

variable "idle_period_minutes" {
  description = "Time (in minutes) for an EC2 instance to remain idle before automatically being stopped"
  type        = string
  default     = "60"
}