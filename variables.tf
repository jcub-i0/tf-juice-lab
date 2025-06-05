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