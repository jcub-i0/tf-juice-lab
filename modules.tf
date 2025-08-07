
# KMS Module for CloudTrail, SNS, SQS, and CloudWatch Log Group

module "kms" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-kms.git?ref=210736c7aaf2394a68e5f85de4e29169ac126363"

  aliases             = ["tf-juice-lab"]
  description         = "KMS key for encrypting CloudTrail, CloudWatch, SNS, SQS"
  enable_key_rotation = true

  key_usage = "ENCRYPT_DECRYPT"

  key_statements = [
    {
      sid    = "AllowCloudTrailToUseKey"
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
        "kms:DescribeKey",
        "kms:CreateGrant"
      ]
      resources = [
        "*"
      ]
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
    }
  ]

  tags = {
    Environment = var.environment
    Project     = "tf-juice-lab"
  }
}