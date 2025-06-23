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
  ami                    = data.aws_ami.kali-linux.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.kali_key.key_name
  vpc_security_group_ids = [aws_security_group.kali_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

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
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.juice_key.key_name
  vpc_security_group_ids = [aws_security_group.juice_sg.id]

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

echo "To troubleshoot, cat into /var/log/cloud-init-output.log"
EOF

  tags = {
    Name = "JuiceShop"
  }
}

# CREATE LOGGING RESOURCES

## Create 8 random digits to tack onto the end of the centralized_logs bucket's name
resource "random_id" "logs_bucket_suffix" {
  byte_length = 2
}

resource "aws_s3_bucket" "centralized_logs" {
  bucket        = "juice-shop-logs-${random_id.logs_bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "Juice Shop Logs"
    Environment = var.environment
  }
}

## Enable SSE encryption on centralized_logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_bucket_encrypt" {
  bucket = aws_s3_bucket.centralized_logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs_bucket" {
  bucket = aws_s3_bucket.centralized_logs.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudtrail" "cloudtrail" {
  depends_on = [
    aws_s3_bucket_policy.cloudtrail_policy,
    aws_iam_role.cloudtrail_to_cw,
    aws_iam_role_policy.cloudtrail_to_cw_policy,
    aws_cloudwatch_log_group.cloudtrail_logs
  ]

  name                          = "CloudTrail"
  s3_bucket_name                = aws_s3_bucket.centralized_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cw.arn

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "tf-juice-lab-cloudtrail"
  retention_in_days = 30

  tags = {
    Name        = "TF-Juice-Lab CloudTrail Logs"
    Environment = var.environment
  }
}

## Create CloudWatch metrics, CloudWatch Alarms, and SNS Topics/Subscriptions

resource "aws_cloudwatch_metric_alarm" "cpu_util" {
  alarm_name                = "cpu_util"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  period                    = 120
  evaluation_periods        = 1
  statistic                 = "Average"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  threshold                 = 80
  alarm_description         = "This metric alerts if CPU utilization exceeds 80% for 2 minutes"
  alarm_actions             = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []
}

## Custom CloudWatch metric based on patterns in logs within CloudWatch Logs
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "Unauthorized-API-Calls"
  pattern        = "{($.errorCode = \"UnauthorizedOperation\") || ($.errorCode = \"AccessDenied\")}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name      = "UnauthorizedAPICallCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name                = "Unauthorized_API_Calls"
  period                    = 180
  evaluation_periods        = 1
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = 1
  statistic                 = "Sum"
  metric_name               = "UnauthorizedAPICallCount"
  namespace                 = "CloudTrailMetrics"
  alarm_description         = "Detect unauthorized API activity"
  alarm_actions             = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []
}

resource "aws_sns_topic" "alerts" {
  name = "tf-juice-lab-alerts"
}

## Consider using a for_each loop for multiple email addresses to be used
resource "aws_sns_topic_subscription" "alerts_sub" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_config_configuration_recorder" "config_rec" {
  name     = "TF-Juice-Lab-Config"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "config_delivery_channel" {
  name           = "Config-Delivery-Channel"
  s3_bucket_name = aws_s3_bucket.centralized_logs.bucket
  depends_on     = [aws_config_configuration_recorder.config_rec]
}

resource "aws_config_configuration_recorder_status" "config_rec_stat" {
  name       = aws_config_configuration_recorder.config_rec.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.config_delivery_channel]
}

## Rule that enforces prohibited public access for S3 buckets
resource "aws_config_config_rule" "s3_public_access_prohibited" {
  name = "s3-public-access-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
  }

  depends_on = [
    aws_config_configuration_recorder_status.config_rec_stat
  ]
}

### Remediation action to automatically disable S3 public read and write
resource "aws_config_remediation_configuration" "disable_public_s3_access" {
  config_rule_name = aws_config_config_rule.s3_public_access_prohibited.name
  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock"

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.config_remediation_role.arn
  }
  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true
  maximum_automatic_attempts = 5
  retry_attempt_seconds      = 120

  depends_on = [aws_iam_role_policy_attachment.config_ssm_automation]
}

resource "aws_config_config_rule" "s3_sse_enabled" {
  name = "s3-sse-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [
    aws_config_configuration_recorder_status.config_rec_stat
  ]
}

resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_guardduty_detector_feature" "features" {
  for_each    = toset(var.guardduty_features)
  detector_id = aws_guardduty_detector.main.id
  name        = each.value
  status      = "ENABLED"
}

# Create EventBridge Rule for AWS GuardDuty
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-findings"
  description = "Trigger on GuardDuty findings"

  event_pattern = jsonencode({
    source = [
      "aws.guardduty"
    ]
    detail-type = [
      "GuardDuty Finding"
    ]
  })
}

# Create EventBridge Target to send events to (target=SNS)
resource "aws_cloudwatch_event_target" "send_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  arn       = aws_sns_topic.alerts.arn
  target_id = "SendToSNS"
}

resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "standards" {
  for_each = var.securityhub_standards
  standards_arn = each.value
  depends_on = [aws_securityhub_account.main]
}