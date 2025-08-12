# KMS Module for CloudTrail, SNS, SQS, and CloudWatch Log Group

module "kms" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-kms.git?ref=210736c7aaf2394a68e5f85de4e29169ac126363"

  aliases             = ["tf-juice-lab"]
  description         = "KMS key for encrypting CloudTrail, CloudWatch, SNS, SQS, Lambda, S3"
  enable_key_rotation = true

  key_usage = "ENCRYPT_DECRYPT"

  key_statements = [
    {
      sid    = "AllowCloudTrailPublishToSNSEncrypted"
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["cloudtrail.amazonaws.com"]
        }
      ]
      actions = [
        "kms:GenerateDataKey*",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    },
    {
      sid    = "AllowSnsDecrypt"
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["sns.amazonaws.com"]
        }
      ]
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:Encrypt",
        "kms:Decrypt"
      ]
      resources = ["*"]
    },
    {
      sid    = "AllowCloudWatchLogs"
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
        }
      ]
      actions = [
        "kms:GenerateDataKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ]
      resources = [
        "*"
      ]
    },
    {
      sid    = "AllowSnsAndSqs"
      effect = "Allow"
      principals = [
        {
          type = "Service"
          identifiers = [
            "sns.amazonaws.com",
            "sqs.amazonaws.com"
          ]
        }
      ]
      actions = [
        "kms:GenerateDataKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ]
      resources = [
        "*"
      ]
    },
    {
      sid    = "AllowEc2IsolateLambdaRole"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = [aws_iam_role.lambda_ec2_isolate_execution_role.arn]
        }
      ]
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    },
    {
      sid    = "AllowEc2AutostopLambdaRole"
      effect = "Allow"

      principals = [
        {
          type        = "AWS"
          identifiers = [aws_iam_role.lambda_autostop_execution_role.arn]
        }
      ]
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    },
    {
      sid    = "AllowIpEnrichLambdaRole"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = [aws_iam_role.lambda_ip_enrich.arn]
        }
      ]
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  ]

  tags = {
    Environment = var.environment
    Project     = "tf-juice-lab"
  }
}

# S3 Module for S3 CRR
module "general_purpose_replica_bucket" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=2a25737a72c7e862ea297cea063207a3aa56b1a8"

  bucket = "general-purpose-replica-${random_id.random_suffix.hex}"
  region = var.secondary_aws_region

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms.key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  /*logging = {
    target_bucket = aws_s3_bucket.centralized_logs.id
    target_prefix = "log/general-purpose-replica/"
  }*/

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = {
    Name        = "General Purpose Replica"
    Environment = var.environment
    Purpose     = "Cross-Region Replication destination bucket"
  }
}