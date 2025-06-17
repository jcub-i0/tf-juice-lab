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

## S3 Bucket Policies
resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.centralized_logs.id

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