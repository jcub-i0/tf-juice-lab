provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "tf-juice-lab" {
  cidr_block = var.vpc_cidr
  tags = {
    Name      = "TF-Juice-Lab"
    Terraform = "true"
  }
}

# CREATE SUBNETS

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.tf-juice-lab.id
  cidr_block        = var.public_sub_cidr
  availability_zone = var.public_sub_az

  tags = {
    Name      = "Public Subnet"
    Terraform = "true"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.tf-juice-lab.id
  cidr_block        = var.private_sub_cidr
  availability_zone = var.private_sub_az

  tags = {
    Name      = "Private Subnet"
    Terraform = "true"
  }
}

# CREATE SECURITY GROUPS

resource "aws_security_group" "juice_sg" {
  name        = "juice-sg"
  description = "Allow traffic from Kali"
  vpc_id      = aws_vpc.tf-juice-lab.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.kali_sg.id]
    description     = "Allow Kali to access JuiceShop"
  }

  tags = {
    Name = "juice_sg"
  }
}

resource "aws_security_group" "kali_sg" {
  name        = "kali-sg"
  description = "Allow SSH and pentest outbound traffic"
  vpc_id      = aws_vpc.tf-juice-lab.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow Bastion Host to access Kali"
  }

  tags = {
    Name = "kali_sg"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow AWS SSM to control the Bastion Host"
  vpc_id      = aws_vpc.tf-juice-lab.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound traffic"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Bastion Host to call on VPC Endpoints related to AWS SSM"
  }

  tags = {
    Name = "bastion_sg"
  }
}

# CREATE EC2 INSTANCES

data "aws_ami" "amz-linux-2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  owners = ["137112412989"]
}

resource "aws_iam_role" "ssm_role" {
  name = "EC2-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy" "ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amz-linux-2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  security_groups             = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  # Install SSM agent on AL2023 Bastion instance
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              EOF
  tags = {
    Name = "Bastion Host"
  }
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2-SSM-Profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_eip" "natgw_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "NATGW"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tf-juice-lab.id

  tags = {
    Name = "IGW"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tf-juice-lab.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tf-juice-lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "private_assc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_assc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# NEXT STEPS: CREATE KALI AND JUICESHOP INSTANCES
# Create S3 buckets using random module for naming conventions