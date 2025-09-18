# DATA BLOCKS

data "aws_iam_policy" "ssm_automation" {
  name = "AmazonSSMAutomationRole"
}

# Fetch information about the AWS identity Terraform is currently using
data "aws_caller_identity" "current" {}

# Fetch details on the current AWS region
data "aws_region" "current" {}
