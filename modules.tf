module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "4.0.0"

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
        "kms:Decrypt",
        "kms:DescribeKey"
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
        "kms:DescribeKey"
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