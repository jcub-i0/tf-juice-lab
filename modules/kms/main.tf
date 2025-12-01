# KMS Module for CloudTrail, SNS, SQS, and CloudWatch Log Group

module "kms" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-kms.git?ref=210736c7aaf2394a68e5f85de4e29169ac126363"

  aliases             = ["tf-juice-lab"]
  description         = "KMS key for encrypting CloudTrail, CloudWatch, SNS, SQS, Lambda, S3"
  enable_key_rotation = true

  key_usage = "ENCRYPT_DECRYPT"

  key_statements = [
    {
      sid    = "AllowS3UseOfKmsKey"
      effect = "Allow"
      principals = [
        {
          type        = "Service"
          identifiers = ["s3.amazonaws.com"]
        }
      ]
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ]
      resources = ["*"]
    },
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
          identifiers = [var.lambda_ec2_isolate_exec_role_arn]
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
          identifiers = [var.lambda_ec2_isolate_exec_role_arn]
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
          identifiers = [var.lambda_ip_enrich_arn]
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

# KMS key for replica bucket (var.secondary_aws_region)
module "kms_replica_secondary_region" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-kms.git?ref=210736c7aaf2394a68e5f85de4e29169ac126363"
  providers = {
    aws = aws.secondary
  }
  enable_key_rotation = true

  key_usage = "ENCRYPT_DECRYPT"

  key_statements = [

    {
      sid    = "AllowReplicationRoleKMS"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = [var.replication_role_arn]
        }
      ]
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = ["*"]
    }
  ]
}