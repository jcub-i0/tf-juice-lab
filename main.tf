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

# DATA BLOCKS

data "aws_ami" "amz-linux-2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  owners = ["137112412989"]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_ami" "kali-linux" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["kali-last-snapshot-amd64-2025.1.4-804fcc46-63fc-4eb6-85a1-50e66d6c7215"]
  }
}

data "aws_iam_policy" "ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

# CREATE PUBLIC AND PRIVATE SUBNETS

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

# CREATE AND ASSOCIATE ROUTE TABLES

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tf-juice-lab.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }
  tags = {
    Name = "Private RT"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tf-juice-lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public RT"
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

# CREATE SECURITY GROUPS

resource "aws_security_group" "juice_sg" {
  name        = "juice-sg"
  description = "Allow traffic from Kali"
  vpc_id      = aws_vpc.tf-juice-lab.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32", var.private_sub_cidr]
    description = "Allow Kali to SSH into Juice instance for app installation"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32", var.private_sub_cidr]
    description = "Allow Kali to access JuiceShop"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion.public_ip}/32"]
    description = "Allow Bastion Host to access Kali"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kali_sg"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow AWS SSM to control the Bastion Host and allow local machine to run pentests via Kali"
  vpc_id      = aws_vpc.tf-juice-lab.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
    description = "Allow local machine to ssh into Bastion instance"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Bastion to call on VPC Endpoints related to AWS SSM"
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.private_sub_cidr]
    description = "Allow outbound ssh traffic on port 22 to private subnet"
  }

  egress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.private_sub_cidr]
    description = "Allow Bastion to forward traffic to Juice Shop over port 3000"
  }

  tags = {
    Name = "bastion_sg"
  }
}

# CREATE AND ATTACH IAM ROLES, INSTANCE PROFILES, ETC

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

resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2-SSM-Profile"
  role = aws_iam_role.ssm_role.name
}

# CREATE EIP, NATGW, AND IGW

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

# CREATE AND LOCALLY SAVE ENCRYPTION KEY PAIRS

resource "tls_private_key" "generate_bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "generate_kali_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "generate_juice_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "bastion_priv_key" {
  content  = tls_private_key.generate_bastion_key.private_key_openssh
  filename = "bastion_priv_key.pem"
}

resource "local_sensitive_file" "kali_priv_key" {
  content  = tls_private_key.generate_kali_key.private_key_openssh
  filename = "kali_priv_key.pem"
}

resource "local_sensitive_file" "juice_priv_key" {
  content  = tls_private_key.generate_juice_key.private_key_openssh
  filename = "juice_priv_key.pem"
}

## chmod 600 all private RSA key files
resource "null_resource" "chmod_priv_keys" {
  provisioner "local-exec" {
    command = "chmod 600 ${local_sensitive_file.bastion_priv_key.filename} ${local_sensitive_file.kali_priv_key.filename} ${local_sensitive_file.juice_priv_key.filename}"
  }
  triggers = {
    timestamp = timestamp()
  }
  depends_on = [local_sensitive_file.kali_priv_key]
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion_key"
  public_key = tls_private_key.generate_bastion_key.public_key_openssh
}

resource "aws_key_pair" "kali_key" {
  key_name   = "kali_key"
  public_key = tls_private_key.generate_kali_key.public_key_openssh
}

resource "aws_key_pair" "juice_key" {
  key_name   = "juice_key"
  public_key = tls_private_key.generate_juice_key.public_key_openssh
}

# CREATE INSTANCES

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amz-linux-2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  security_groups             = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.bastion_key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  # Install SSM agent on Bastion (AL2023) instance
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

# ATTACH JUICE SHOP-INSTALLED EBS VOLUME TO JUICE SHOP INSTANCE


resource "aws_instance" "kali" {
  ami                  = data.aws_ami.kali-linux.id
  instance_type        = "t3.medium"
  subnet_id            = aws_subnet.private.id
  key_name             = aws_key_pair.kali_key.key_name
  security_groups      = [aws_security_group.kali_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  root_block_device {
    volume_size = "50"
    volume_type = "gp3"
  }

  # Install and start SSM agent and install pentesting tools on Kali (Debian) instance
  user_data = <<-EOF
#!/bin/bash
set -eux

export DEBIAN_FRONTEND=noninteractive

apt update -y
apt install -y wget curl unzip

# Download latest SSM Agent .deb package and install package
wget https://s3.amazonaws.com/amazon-ssm-us-east-1/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb || apt install -f -y

# Enable and start the SSM service
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install CLI tools necessary to pentest Juice Shop
apt install -y \
  httpie \
  nmap \
  whatweb \
  gobuster \
  ffuf \
  sqlmap \
  nikto \
  hydra \
  seclists
echo "CLI pentesting tools installed: httpie, nmap, whatweb, gobuster, ffuf, sqlmap, nikto, hydra, seclists"
EOF

  tags = {
    Name = "Kali"
  }
}

resource "aws_instance" "juice-shop" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.medium"
  subnet_id       = aws_subnet.private.id
  key_name        = aws_key_pair.juice_key.key_name
  security_groups = [aws_security_group.juice_sg.id]

  root_block_device {
    volume_size = "40"
    volume_type = "gp3"
  }

  user_data = <<EOF
#!/bin/bash

sudo apt update -y

# Inline DEBIAN_FRONTEND with each apt call to suppress popups
sudo DEBIAN_FRONTEND=noninteractive apt install -y git curl build-essential python3

# Install latest LTS version of Node
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

# Clone OWASP Juice Shop's repository
cd /home/ubuntu
git clone https://github.com/juice-shop/juice-shop.git --depth 1
cd juice-shop

# Install NPM, launch Juice Shop application, and let it run in the background
npm install
nohup npm start > juice.log 2>&1 &
EOF

  tags = {
    Name = "JuiceShop"
  }
}

# NEXT STEPS: Create an S3 bucket for CloudTrail logs and configure CloudTrail