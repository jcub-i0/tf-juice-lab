variable "private_sub_cidr" {
  description = "CIDR address for the Private Subnet"
  type        = string
}

variable "bastion_allowed_cidrs" {
  description = "The CIDR(s) of the local machine(s) allowed to access the Bastion Host instance"
  type        = list(string)
}