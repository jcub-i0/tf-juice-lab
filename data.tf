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

data "aws_iam_policy" "ssm_automation" {
  name = "AmazonSSMAutomationRole"
}

# Fetch information about the AWS identity Terraform is currently using
data "aws_caller_identity" "current" {}

# IAM Trust Policy for AWS Config
data "aws_iam_policy_document" "assume_role_config" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "config_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "config:BatchGetResourceConfig",
      "config:Put*",
      "config:Get*",
      "config:Describe*",
      "s3:PutObject",
      "s3:GetBucketAcl",
      "sns:Publish",
      "iam:Get*",
      "ec2:Describe*",
      "rds:Describe*",
      "lambda:List*",
      "lambda:Get*"
    ]
    resources = ["*"]
  }
}

# IAM Trust Policy for Lambda
data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_permissions"{
  statement {
    effect = "Allow"
    actions = [
      "ec2:ModifyInstanceAttribute",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.centralized_logs.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}