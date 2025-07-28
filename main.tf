terraform {
  required_version = "~>1.12.0"

  backend "s3" {
    bucket  = "tf-juice-lab-state"
    key     = "tf-juice-lab-state/tf-state"
    region  = "us-east-1"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0-beta2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "tf-juice-lab" {
  cidr_block = var.vpc_cidr
  tags = {
    Name      = "TF-Juice-Lab"
    Terraform = "true"
  }
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
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
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

resource "aws_security_group" "quarantine_sg" {
  name        = "quarantine-sg"
  description = "Security Group to send compromised EC2 instances to for isolation"
  vpc_id      = aws_vpc.tf-juice-lab.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow only HTTPS for SSM"
  }

  tags = {
    Name = "quarantine_sg"
  }
}

# CREATE NACLs
## Create and configure Public NACL
resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.tf-juice-lab.id
  subnet_ids = [aws_subnet.public.id]
  tags = {
    Name = "Public_NACL"
  }
}

### Public NACL ingress rules
resource "aws_network_acl_rule" "public_nacl_ingress_allowed_ips" {
  for_each       = toset(var.bastion_allowed_cidrs)
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "public_nacl_ingress_ephemeral" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 125
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

### Public NACL egress rules
resource "aws_network_acl_rule" "public_nacl_egress_ephemeral" {
  egress         = true
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 175
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_nacl_egress" {
  egress         = true
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.public_sub_cidr
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "public_nacl_egress_3000" {
  egress         = true
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 125
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.private_sub_cidr
  from_port      = 3000
  to_port        = 3000
}

resource "aws_network_acl_rule" "public_nacl_egress_ssm" {
  egress         = true
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 150
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

## Create and configure Private NACL
resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.tf-juice-lab.id
  subnet_ids = [aws_subnet.private.id]

  tags = {
    Name = "Private_NACL"
  }
}

### Private NACL ingress rules
resource "aws_network_acl_rule" "private_nacl_ingress_ssh" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.public_sub_cidr
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "private_nacl_ingress_juice" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.public_sub_cidr
  from_port      = 3000
  to_port        = 3000
}

#### Allow return traffic from Internet/Bastion/etc
resource "aws_network_acl_rule" "private_nacl_ingress_ephemeral" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

### Private NACL egress rules
#### Allow EC2 instances to reach Internet or Bastion Host (all traffic)
resource "aws_network_acl_rule" "private_nacl_egress_ssh" {
  egress         = true
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 150
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
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
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.bastion_key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  root_block_device {
    tags = {
      Name = "Bastion_Volume"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  # Install SSM agent on Bastion (AL2023) instance
  user_data = <<-EOF
#!/bin/bash
apt -o Acquire::ForceIPv4=true update
yum update -y
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
EOF
  tags = {
    Name = "BastionHost"
  }
}

resource "aws_instance" "kali" {
  ami                    = data.aws_ami.kali-linux.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.kali_key.key_name
  vpc_security_group_ids = [aws_security_group.kali_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = "50"
    volume_type = "gp3"
    tags = {
      Name = "Kali_Volume"
    }
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
  netcat-openbsd \
  seclists
echo "CLI pentesting tools installed: httpie, nmap, whatweb, gobuster, ffuf, sqlmap, nikto, hydra, seclists"
EOF

  tags = {
    Name = "Kali"
  }
}

resource "aws_instance" "juice-shop" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.juice_key.key_name
  vpc_security_group_ids = [aws_security_group.juice_sg.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = "40"
    volume_type = "gp3"
    tags = {
      Name = "JuiceShop_Volume"
    }

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

echo "To troubleshoot, cat into /var/log/cloud-init-output.log"
EOF

  tags = {
    Name = "JuiceShop"
  }
}

## Create 8 random digits to tack onto resources that require a unique name
resource "random_id" "random_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "general_purpose" {
  bucket = "general-purpose-${random_id.random_suffix.hex}"

  tags = {
    Name        = "General Purpose"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "general_purpose_sse" {
  bucket = aws_s3_bucket.general_purpose.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "general_purpose_versioning" {
  bucket = aws_s3_bucket.general_purpose.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

# Random comment to test GitHub workflow