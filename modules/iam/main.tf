## Create SSM IAM Role for EC2 resources
resource "aws_iam_role" "ssm_role" {
  name = "EC2-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy" "ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2-SSM-Profile"
  role = aws_iam_role.ssm_role.name
}


## S3 Bucket policy for replica buckets
resource "aws_iam_role" "replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })
}

## IAM policy for General Purpose Replica bucket to allow General Purpose S3 to perform CRR
resource "aws_iam_role_policy" "replication_policy" {
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permissions for General Purpose source bucket
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:ListBucket"
        ]
        Resource = [
          var.gen_purp_bucket_arn,
          "${var.gen_purp_bucket_arn}/*"
        ]
      },
      # Permissions for General Purpose Replica bucket
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Resource = [
          module.general_purpose_replica_bucket.s3_bucket_arn,
          "${module.general_purpose_replica_bucket.s3_bucket_arn}/*"
        ]
      },
      # Permissions for Centralized Logs source bucket
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.centralized_logs.arn,
          "${aws_s3_bucket.centralized_logs.arn}/*"
        ]
      },
      # Permissions for Centralized Logs Replica bucket
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Resource = [
          module.centralized_logs_replica_bucket.s3_bucket_arn,
          "${module.centralized_logs_replica_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [
          module.kms.key_arn,
          module.kms_replica_secondary_region.key_arn
        ]
      }
    ]
  })
}

## Allow CloudTrail to access CloudWatch Logs
resource "aws_iam_role" "cloudtrail_to_cw" {
  name = "cloudtrail-to-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowCloudTrailToCloudWatch"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_to_cw_policy" {
  name = "cloudtrail-to-cw-policy"
  role = aws_iam_role.cloudtrail_to_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
      }
    ]
  })
}

# Config IAM resources
## Create IAM role for AWS Config
resource "aws_iam_role" "config_role" {
  name               = "config_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_config.json
}

## Attach AWS Config managed policy
resource "aws_iam_role_policy" "config_policy" {
  name   = "config-policy"
  role   = aws_iam_role.config_role.id
  policy = data.aws_iam_policy_document.config_permissions.json
}

resource "aws_iam_role_policy_attachment" "config_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

## Config Remediation
resource "aws_iam_role" "config_remediation_role" {
  name = "ConfigRemediationRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ssm.amazonaws.com"
      },
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = var.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_ssm_automation" {
  role       = aws_iam_role.config_remediation_role.name
  policy_arn = data.aws_iam_policy.ssm_automation.arn
}

/*
Give Config remediation's SSM Automation document explicit permissions to read and modify public
access on all S3 buckets and to read and update the bucket's policy if needed
*/
resource "aws_iam_role_policy" "config_remediation_policy" {
  name = "ConfigRemediationPolicy"
  role = aws_iam_role.config_remediation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy"
        ],
        Resource = "*"
      }
    ]
  })
  #checkov:skip=CKV_AWS_355: This policy requires "*" because the remediation must apply to any S3 bucket in the account
  #checkov:skip=CKV_AWS_289 Remediation requires ability to modify bucket policy/public access for any bucket in account
}

# Lambda IAM resources

## Allow Lambda to publish to Alerts SNS topic
resource "aws_iam_policy" "lambda_sns_publish_policy" {
  name = "lambda_sns_publish_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "sns:Publish",
        ],
        Effect   = "Allow",
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

## Lambda EC2 Isolation IAM resources
### Lambda execution role for lambda ec2 isolation
resource "aws_iam_role" "lambda_ec2_isolate_execution_role" {
  name               = "lambda_ec2_isolate_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

### Attach permissions to the Lambda ec2 isolation func's Execution Role
resource "aws_iam_role_policy" "lambda_ec2_isolate_policy" {
  name   = "lambda_ec2_isolate_policy"
  role   = aws_iam_role.lambda_ec2_isolate_execution_role.id
  policy = data.aws_iam_policy_document.lambda_ec2_isolate_permissions.json
}

### Attach IAM policy that allows Lambda ec2 isolate func read access to General Purpose S3
resource "aws_iam_role_policy" "lambda_general_purpose_s3_read" {
  name   = "lambda_general_purpose_s3_read"
  role   = aws_iam_role.lambda_ec2_isolate_execution_role.id
  policy = data.aws_iam_policy_document.lambda_general_purpose_s3_read.json
}

### Attach IAM policy that allows Lambda EC2 Isolate func to publish to SNS Alerts topic
resource "aws_iam_role_policy_attachment" "lambda_isolate_sns_attach" {
  role       = aws_iam_role.lambda_ec2_isolate_execution_role.name
  policy_arn = aws_iam_policy.lambda_sns_publish_policy.arn
}

## Lambda Auto Stop on Idle IAM resources
### Enable Lambda Autostop to assume IAM role
resource "aws_iam_role" "lambda_autostop_execution_role" {
  name               = "lambda_autostop_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy" "lambda_autostop_policy" {
  name   = "lambda_autostop_policy"
  role   = aws_iam_role.lambda_autostop_execution_role.id
  policy = data.aws_iam_policy_document.lambda_ec2_autostop_permissions.json
}

### Attach Lambda SNS publish policy to Lambda Autostop func's execution role
resource "aws_iam_role_policy_attachment" "lambda_autostop_sns_attach" {
  role       = aws_iam_role.lambda_autostop_execution_role.name
  policy_arn = aws_iam_policy.lambda_sns_publish_policy.arn
}

## Lambda IP Enrichment IAM resources
### IP Enrich execution role
resource "aws_iam_role" "lambda_ip_enrich" {
  name               = "lambda_ip_enrich_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
}

resource "aws_iam_role_policy" "lambda_ip_enrich_policy" {
  name   = "lambda_ip_enrich_policy"
  role   = aws_iam_role.lambda_ip_enrich.id
  policy = data.aws_iam_policy_document.ip_enrich_permissions.json
}

### Attach Lambda SNS Publish policy to IP Enrichment func's execution role
resource "aws_iam_role_policy_attachment" "lambda_ip_enrich_sns_attach" {
  role       = aws_iam_role.lambda_ip_enrich.id
  policy_arn = aws_iam_policy.lambda_sns_publish_policy.arn
}

# Create IAM policy that allows Terraform admin user read and write access to General Purpose S3 bucket
resource "aws_iam_policy" "terraform_s3_write_policy" {
  name   = "terraform_s3_write_policy"
  policy = data.aws_iam_policy_document.terraform_s3_write.json
}

# Attach IAM policy that allows Terraform admin user read and write access to General Purpose S3 bucket
resource "aws_iam_policy_attachment" "terraform_s3_write_policy_attach" {
  name = "terraform_s3_write_policy_attach"
  users = [
    var.terraform_admin_username
  ]
  policy_arn = aws_iam_policy.terraform_s3_write_policy.arn
}

# IAM Policies for VPC Flow Logs to be sent to Flow Logs CloudWatch Log Group
resource "aws_iam_role" "vpc_flow_logs" {
  name               = "vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
}

resource "aws_iam_role_policy" "vpc_flow_logs_inline" {
  name   = "vpc-flow-logs-policy"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_inline_policy.json
}