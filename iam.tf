# CREATE AND ATTACH IAM ROLES, INSTANCE PROFILES, ETC

# S3 Bucket Policies

## S3 bucket policy to allow Lambda EC2 Isolation func and the Terraform admin user read access to the General Purpose S3 bucket
resource "aws_s3_bucket_policy" "general_purpose_policy" {
  bucket = aws_s3_bucket.general_purpose.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Allow EC2 Isolation Lambda func access to General Purpose S3 bucket"
        Effect = "Allow",
        Principal = {
          AWS = [
            module.iam.lambda_ec2_isolate_execution_role_arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.terraform_admin_username}"
          ]
        },
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = "${aws_s3_bucket.general_purpose.arn}/*"
      },
      {
        Sid    = "AllowReplicationRoleReadFromSource"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.replication_role_arn
        }
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectLegalHold",
          "s3:GetObjectRetention",
          "s3:GetObjectTagging",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          aws_s3_bucket.general_purpose.arn,
          "${aws_s3_bucket.general_purpose.arn}/*"
        ]
      }
    ]
  })
}

### Attach IAM policy that allows General Purpose S3 Notifications SNS to send messages to SQS
resource "aws_sqs_queue_policy" "gen_purp_s3_sns_to_sqs" {
  queue_url = aws_sqs_queue.general_purpose_s3_event_queue.id
  policy    = module.iam.gen_purp_s3_sns_to_sqs_json
}

### Attach IAM policy that allows General Purpose S3 to publish to Centralized Logs SNS topic
resource "aws_sns_topic_policy" "general_purpose_topic_policy" {
  arn    = aws_sns_topic.general_purpose_bucket_notifications.arn
  policy = module.iam.general_purpose_sns_policy_json
}

### Attach IAM policy that allows Centralized Logs S3 Notifications SNS to send messages to SQS
resource "aws_sqs_queue_policy" "centralized_logs_s3_sns_to_sqs" {
  queue_url = aws_sqs_queue.centralized_logs_s3_event_queue.id
  policy    = module.iam.centralized_logs_s3_sns_to_sqs_json
}

### Attach IAM policy that allows Centralized Logs S3 to publish to Centralized Logs SNS topic
resource "aws_sns_topic_policy" "centralized_logs_topic_policy" {
  arn    = aws_sns_topic.centralized_logs_bucket_notifications.arn
  policy = module.iam.centralized_logs_topic_policy_json
}

resource "aws_s3_bucket_policy" "general_purpose_replica_policy" {
  provider = aws.secondary
bucket   = module.s3_replication.general_purpose_replica_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReplicationRoleWriteToReplica"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.replication_role_arn
        }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [
          module.general_purpose_replica_bucket.s3_bucket_arn,
          "${module.general_purpose_replica_bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "centralized_logs_replica_policy" {
  provider = aws.secondary
  bucket   = module.centralized_logs_replica_bucket.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowReplicationRoleWriteToLogsReplica"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.replication_role_arn
        }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [
          module.centralized_logs_replica_bucket.s3_bucket_arn,
          "${module.centralized_logs_replica_bucket.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

## Allow CloudTrail to publish to CloudTrail Notifications SNS Topic
resource "aws_sns_topic_policy" "cloudtrail_sns_policy" {
  arn = aws_sns_topic.cloudtrail_notifications.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudTrailPublish",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "sns:Publish",
        Resource = aws_sns_topic.cloudtrail_notifications.arn
      }
    ]
  })
}

## Allow CloudTrail Notifications SNS Topic to publish to CloudTrail SQS queue
resource "aws_sqs_queue_policy" "cloudtrail_sns_to_sqs_policy" {
  queue_url = aws_sqs_queue.cloudtrail_log_delivery.id
  policy    = module.iam.cloudtrail_sns_sqs_json
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

### Allow EventBridge to invoke Lambda EC2 Isolation func
resource "aws_lambda_permission" "allow_eventbridge_invoke_ec2_isolation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_isolation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_ec2_isolate.arn
}

### Attach IAM policy to EC2 Isolate SQS DLQ so Lambda can send it messages
resource "aws_sqs_queue_policy" "ec2_isolate_dlq_policy" {
  queue_url = aws_sqs_queue.ec2_isolation_dlq.id
  policy    = module.iam.ec2_isolate_lambda_to_sqs_json
}

### Allow EventBridge to invoke Lambda EC2 Autostop function
resource "aws_lambda_permission" "allow_eventbridge_invoke_ec2_autostop" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_autostop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_autostop_schedule.arn
}

### Attach IAM policy to EC2 AutoStop SQS DLQ so Lambda can send it messages
resource "aws_sqs_queue_policy" "ec2_autostop_lambda_to_sqs" {
  queue_url = aws_sqs_queue.ec2_autostop_dlq.id
  policy    = module.iam.ec2_autostop_lambda_to_sqs_json
}

resource "aws_lambda_permission" "eventbridge_invoke_ip_enrich" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ip_enrich.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_finding_event.arn
}

### Attach IAM policy to EC2 IP Enrich SQS DLQ so Lambda can send it messages
resource "aws_sqs_queue_policy" "ip_enrich_lambda_to_sqs" {
  queue_url = aws_sqs_queue.ip_enrich_dlq.id
  policy    = module.iam.ip_enrich_lambda_to_sqs_json
}