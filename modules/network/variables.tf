variable "vpc_cidr" {
  type = string
}

variable "public_sub_cidr" {
  description = "CIDR address for the Public Subnet"
  type        = string
}

variable "public_sub_az" {
  description = "Availability Zone for the Public Subnet"
  type        = string
}

variable "private_sub_cidr" {
  description = "CIDR address for the Private Subnet"
  type        = string
}

variable "private_sub_az" {
  description = "Availability Zone for the Private Subnet"
  type        = string
}

variable "lambda_sub_cidr" {
  description = "CIDR address for the Lambda Private Subnet"
  type        = string
}

variable "lambda_sub_az" {
  description = "Availability Zone for the Lambda Private Subnet"
  type        = string
}