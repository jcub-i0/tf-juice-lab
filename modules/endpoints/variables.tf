variable "aws_region" {
  description = "The primary AWS Region that the cloud environment uses"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID of the main VPC"
  type        = string
}

variable "lambda_subnet_id" {
  description = "The Lambda function subnet's ID"
  type        = string
}

variable "vpc_endpoints_sg_id" {
  description = "The ID of the VPC Endpoints Security Group"
  type        = string
}