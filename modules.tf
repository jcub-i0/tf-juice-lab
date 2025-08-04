module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "4.0.0"

  aliases             = ["tf-juice-lab"]
  description         = "KMS key for encrypting CloudTrail, CloudWatch, SNS, SQS"
  enable_key_rotation = true

  key_usage = "ENCRYPT_DECRYPT"

  tags = {
    Environment = var.environment
    Project     = "tf-juice-lab"
  }
}