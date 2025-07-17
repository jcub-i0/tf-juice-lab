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

# Lambda IAM
## IAM trust policy document for Lambda functions
data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

## IAM permission policy to allow Lambda read access to General Purpose S3 bucket
data "aws_iam_policy_document" "lambda_general_purpose_s3_read" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.general_purpose.arn}/*"
    ]
  }
}

## IAM permission policy document for Lambda EC2 isolation function
data "aws_iam_policy_document" "lambda_ec2_isolate_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:ModifyInstanceAttribute",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:CreateTags",
      "ec2:CreateSnapshot"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.centralized_logs.bucket}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "cloudtrail:LookupEvents"
    ]
    resources = ["*"]
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

## IAM permission policy for EC2 Auto Stop on Idle Lambda function
data "aws_iam_policy_document" "lambda_ec2_autostop_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:StopInstances",
      "ec2:CreateTags"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics"
    ]
    resources = ["*"]
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

## Lambda permission policy for IP Enrichment function
data "aws_iam_policy_document" "ip_enrich_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "securityhub:GetFindings"
    ]
    resources = ["*"]
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

# IAM policy document granting Terraform read and write access to objects in the General Purpose S3 bucket
data "aws_iam_policy_document" "terraform_s3_write" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "${aws_s3_bucket.general_purpose.arn}/*"
    ]
  }
}