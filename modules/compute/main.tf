# CREATE SECURITY GROUPS

## Default securuity group restricts all traffic
resource "aws_default_security_group" "default" {
  vpc_id = module.network.vpc_id
  tags = {
    Name = "default_sg"
  }
}

resource "aws_security_group" "juice_sg" {
  name        = "juice-sg"
  description = "Allow traffic from Kali"
  vpc_id      = module.network.vpc_id

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
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound HTTP traffic"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound HTTPS traffic"
  }

  tags = {
    Name = "juice_sg"
  }
}

resource "aws_security_group" "kali_sg" {
  name        = "kali-sg"
  description = "Allow SSH and pentest outbound traffic"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
    description = "Allow Bastion Host to access Kali"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound HTTP traffic"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound HTTPS traffic"
  }

  tags = {
    Name = "kali_sg"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow AWS SSM to control the Bastion Host and allow local machine to run pentests via Kali"
  vpc_id      = module.network.vpc_id

  dynamic "ingress" {
    for_each = toset(var.bastion_allowed_cidrs)
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Allow local machine to ssh into Bastion instance"
    }
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
  instance_type               = "t3.micro"
  subnet_id                   = module.network.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.bastion_key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  monitoring                  = true

  #checkov:skip=CKV_AWS_88: Bastion Host requires public IP address for controlled lab SSH chaining from local machine; ingress SG rules are IP-restricted
  #checkov:skip=CKV_AWS_135: This instance is EBS optimized, despite what Checkov says; t3 instance types are EBS optimized.

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
  subnet_id              = module.network.private_subnet_id
  key_name               = aws_key_pair.kali_key.key_name
  vpc_security_group_ids = [aws_security_group.kali_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  monitoring             = true

  #checkov:skip=CKV_AWS_135: This instance is EBS optimized, despite what Checkov says; t3 instance types are EBS optimized.

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
  subnet_id              = module.network.private_subnet_id
  key_name               = aws_key_pair.juice_key.key_name
  vpc_security_group_ids = [aws_security_group.juice_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  monitoring             = true

  #checkov:skip=CKV_AWS_135: This instance is EBS optimized, despite what Checkov says; t3 instance types are EBS optimized.  

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

## Create SSM IAM Role
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