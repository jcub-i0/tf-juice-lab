provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "tf-juice-lab" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "TF-Juice-Lab"
      Terraform = "true"
    }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.tf-juice-lab.id
  cidr_block = var.public_sub_cidr
  availability_zone = var.public_sub_az

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.tf-juice-lab.id
  cidr_block = var.private_sub_cidr
  availability_zone = var.private_sub_az

  tags = {
    Name = "Private Subnet"
  }
}