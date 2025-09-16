variable "vpc_id" {
  description = "The VPC ID from the network module"
  type        = string
}

variable "public_subnet_id" {
  description = "The public subnet ID for the bastion host"
  type        = string
}

variable "private_subnet_id" {
  description = "The private subnet ID for Kali and Juice Shop instances"
  type        = string
}

variable "private_sub_cidr" {
  description = "CIDR address for the Private Subnet"
  type        = string
}

variable "bastion_allowed_cidrs" {
  description = "The CIDR(s) of the local machine(s) allowed to access the Bastion Host instance"
  type        = list(string)
}

variable "ssm_instance_profile_name" {
  description = "Value of the 'name' attribute for the SSM instance profile"
  type        = string
}