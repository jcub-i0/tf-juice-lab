# CREATE AND ATTACH IAM ROLES, INSTANCE PROFILES, ETC

## Create SSM IAM Role
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

resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2-SSM-Profile"
  role = aws_iam_role.ssm_role.name
}

# S3 Bucket Policies
## S3 Bucket policy to allow CloudTrail to put objects in Centralized Logs bucket
resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.centralized_logs.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.centralized_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailListBucket"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.centralized_logs.arn
        Condition = {
          StringEquals = {
            "s3:prefix" = "AWSLogs/${data.aws_caller_identity.current.account_id}/"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailGetBucketAcl"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.centralized_logs.arn
      }
    ]
  })
}

## S3 bucket policy to allow Lambda EC2 Isolation func and the Terraform admin user read access to the General Purpose S3 bucket
resource "aws_s3_bucket_policy" "general_purpose_policy" {
  bucket = aws_s3_bucket.general_purpose.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = [
            aws_iam_role.lambda_ec2_isolate_execution_role.arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.terraform_admin_username}"
          ]
        },
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = "${aws_s3_bucket.general_purpose.arn}/*"
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
}

# Permit EventBridge to publish to "Alerts" SNS topic
resource "aws_sns_topic_policy" "sns_policy" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowEventBridgePublish",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish",
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Lambda IAM resources
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

### Allow EventBridge to invoke Lambda EC2 Isolation func
resource "aws_lambda_permission" "allow_eventbridge_invoke_ec2_isolation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_isolation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_ec2_isolate.arn
}

### Attach IAM policy that allows Lambda ec2 isolate func read access to General Purpose S3
resource "aws_iam_role_policy" "lambda_general_purpose_s3_read" {
  name   = "lambda_general_purpose_s3_read"
  role   = aws_iam_role.lambda_ec2_isolate_execution_role.id
  policy = data.aws_iam_policy_document.lambda_general_purpose_s3_read.json
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

### Allow EventBridge to invoke Lambda EC2 Autostop function
resource "aws_lambda_permission" "allow_eventbridge_invoke_ec2_autostop" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_autostop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_autostop_schedule.arn
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