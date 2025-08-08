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

# Fetch details on the current AWS region
data "aws_region" "current" {}

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
  #checkov:skip=CKV_AWS_356: AWS Config requires wildcard resource access for full resource monitoring
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
    sid    = "KMSDecryptEncrypt"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [module.kms.key_arn]
  }
  statement {
    sid    = "EC2IsolationActions"
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
    sid    = "AllowEC2NetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "SNSPublish"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [aws_sns_topic.alerts.arn]
  }
  statement {
    sid = "SecurityHubRead"
    actions = [
      "securityhub:GetFindings"
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
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [
      aws_sqs_queue.ec2_isolation_dlq.arn
    ]
  }
}

## IAM permission policy for EC2 Auto Stop on Idle Lambda function
data "aws_iam_policy_document" "lambda_ec2_autostop_permissions" {
  statement {
    sid    = "KMSDecryptEncrypt"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [module.kms.key_arn]
  }
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
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [aws_sqs_queue.ec2_autostop_dlq.arn]
  }
  statement {
    sid    = "AllowEC2NetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ]
    resources = ["*"]
  }
}

## Lambda permission policy for IP Enrichment function
data "aws_iam_policy_document" "ip_enrich_permissions" {
  statement {
    sid    = "KMSDecryptEncrypt"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [module.kms.key_arn]
  }
  statement {
    sid    = "AllowSecurityHubRead"
    effect = "Allow"
    actions = [
      "securityhub:GetFindings"
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
    resources = ["*"]
  }
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
  statement {
    sid    = "SNSPublish"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [aws_sns_topic.alerts.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [aws_sqs_queue.ec2_ip_enrich_dlq.arn]
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

# Create IAM policy document to allow CloudTrail SNS topic to publish to CloudTrail SQS qeueue
data "aws_iam_policy_document" "cloudtrail_sns_to_sqs" {
  statement {
    sid    = "Allow-SNS-SendMessage"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "SQS:SendMessage",
    ]

    resources = [aws_sqs_queue.cloudtrail_log_delivery.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.cloudtrail_notifications.arn]
    }
  }
}

# Create IAM policy document to allow EC2 Isolation Lambda to publish to EC2 Isolation SQS DLQ
data "aws_iam_policy_document" "ec2_isolate_lambda_to_sqs" {
  statement {
    sid    = "Allow-Ec2-Isolate-Lambda-To-Sqs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [aws_sqs_queue.ec2_isolation_dlq.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_lambda_function.ec2_isolation.arn]
    }
  }
}

# Create IAM policy document to allow EC2 AutoStop Lambda to publish to EC2 AutoStop SQS DLQ
data "aws_iam_policy_document" "ec2_autostop_lambda_to_sqs" {
  statement {
    sid    = "Allow-Ec2-AutoStop-Lambda-To-Sqs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [aws_sqs_queue.ec2_autostop_dlq.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_lambda_function.ec2_autostop.arn]
    }
  }
}

# Create IAM policy document to allow EC2 AutoStop Lambda to publish to EC2 AutoStop SQS DLQ
data "aws_iam_policy_document" "ec2_ip_enrich_lambda_to_sqs" {
  statement {
    sid    = "Allow-Ec2-IpEnrich-Lambda-To-Sqs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [aws_sqs_queue.ec2_ip_enrich_dlq.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_lambda_function.ip_enrich.arn]
    }
  }
}

# General Purpose SQS policy
data "aws_iam_policy_document" "gen_purp_s3_sns_to_sqs" {
  version = "2012-10-17"
  statement {
    sid    = "AllowGeneralPurposeS3SnsToMessageSqs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]
    resources = [aws_sqs_queue.general_purpose_s3_event_queue.arn]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.general_purpose_bucket_notifications.arn]
    }
  }
}

# SNS policy allowing Genreal Purpose S3 to publish events to General Purpose SNS topic
data "aws_iam_policy_document" "general_purpose_sns_policy" {
  version = "2012-10-17"
  statement {
    sid    = "AllowGeneralPurposeS3Publish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "sns:Publish"
    ]

    resources = [aws_sns_topic.general_purpose_bucket_notifications.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.general_purpose.arn]
    }
  }
}

# Centralized Logs SQS Policy
data "aws_iam_policy_document" "centralized_logs_s3_sns_to_sqs" {
  version = "2012-10-17"
  statement {
    sid    = "AllowCentralizedLogsS3SnsToMessageSqs"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [aws_sqs_queue.centralized_logs_s3_event_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.centralized_logs_bucket_notifications.arn]
    }
  }
}

# SNS topic policy allowing Centralized Logs S3 to publish events to Centralized Logs SNS topic
data "aws_iam_policy_document" "centralized_logs_sns_policy" {
  version = "2012-10-17"
  statement {
    sid    = "AllowCentralizedLogsS3Publish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sns:Publish"]

    resources = [aws_sns_topic.centralized_logs_bucket_notifications.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.centralized_logs.arn]
    }
  }
}

# IAM Policies for VPC Flow Logs to be sent to Flow Logs CloudWatch Log Group
data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_inline_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}