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
    "LAMBDA_NETWORK_LOGS"
  ]
}

variable "securityhub_standards" {
  description = "Map of short-named Security Hub standards to their ARNs"
  type = map(string)
  default = {
    # Each value (arn) is specific to the us-east-1 region. Replace it with the region your infrastructure is deployed in.
    aws_fsbp = "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0",
    cis = "arn:aws:securityhub:us-east-1::standards/cis-aws-foundations-benchmark/v/3.0.0",
    nist_800 = "arn:aws:securityhub:us-east-1::standards/nist-800-53/v/5.0.0",
    pci_dss = "arn:aws:securityhub:us-east-1::standards/pci-dss/v/3.2.1"
  }
}