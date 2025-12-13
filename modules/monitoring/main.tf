# MONITORING/SECURITY RESOURCES

locals {
  # SecurityHub standards for securityhub_standards_subscriptions resource to loop through
  ## Select the SecurityHub standards you want by uncommenting the respective standard(s)
  securityhub_standards = {
    aws_fsbp = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0",
    #cis = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/3.0.0",
    #nist_800 = "arn:aws:securityhub:${var.aws_region}::standards/nist-800-53/v/5.0.0",
    #pci_dss = "arn:aws:securityhub:${var.aws_region}::standards/pci-dss/v/3.2.1"
  }
}

# Enable VPC Flow Logs and send them to specific CloudWatch Logs Group
## VPC Flow Log resource
resource "aws_flow_log" "main_vpc" {
  iam_role_arn         = var.vpc_flow_logs_arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs_group.arn
  traffic_type         = "ALL"
  vpc_id               = var.vpc_id

  tags = {
    Name = "TF-Juice-Lab VPC Flow Logs"
  }

}

## Create CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs_group" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "tf-juice-lab-cloudtrail"
  retention_in_days = 365
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "TF-Juice-Lab CloudTrail Logs"
    Environment = var.environment
  }
}

## Create CloudWatch metrics, CloudWatch Alarms, and SNS Topics/Subscriptions

resource "aws_cloudwatch_metric_alarm" "cpu_util" {
  alarm_name                = "cpu_util"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  period                    = 120
  evaluation_periods        = 1
  statistic                 = "Average"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  threshold                 = 80
  alarm_description         = "This metric alerts if CPU utilization exceeds 80% for 2 minutes"
  alarm_actions             = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []
}

## Custom CloudWatch metric based on patterns in logs within CloudWatch Logs
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "Unauthorized-API-Calls"
  pattern        = "{($.errorCode = \"UnauthorizedOperation\") || ($.errorCode = \"AccessDenied\")}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name      = "UnauthorizedAPICallCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name                = "Unauthorized_API_Calls"
  period                    = 180
  evaluation_periods        = 1
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  threshold                 = 1
  statistic                 = "Sum"
  metric_name               = "UnauthorizedAPICallCount"
  namespace                 = "CloudTrailMetrics"
  alarm_description         = "Detect unauthorized API activity"
  alarm_actions             = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []
}

resource "aws_sns_topic" "alerts" {
  name              = "tf-juice-lab-security-alerts"
  kms_master_key_id = var.kms_key_arn
}

resource "aws_sns_topic_subscription" "alerts_sub" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# Create SNS topic for CloudTrail notificaitons
resource "aws_sns_topic" "cloudtrail_notifications" {
  name              = "cloudtrail-log-delivery"
  kms_master_key_id = var.kms_key_arn
}

# Create SQS queue for CloudTrail notifications
resource "aws_sqs_queue" "cloudtrail_log_delivery" {
  name              = "cloudtrail-log-delivery-queue"
  kms_master_key_id = var.kms_key_arn
}

# Create SNS topic subscription for CloudTrail notifications
resource "aws_sns_topic_subscription" "cloudtrail_notifications_sub" {
  topic_arn            = aws_sns_topic.cloudtrail_notifications.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.cloudtrail_log_delivery.arn
  raw_message_delivery = true
}


resource "aws_config_configuration_recorder" "config_rec" {
  name     = "TF-Juice-Lab-Config"
  role_arn = var.config_role_arn

  # This only records EC2 and S3 resources -- change it according to your preferences
  recording_group {
    all_supported                 = false
    include_global_resource_types = false

    resource_types = [
      "AWS::EC2::Instance",
      "AWS::S3::Bucket"
    ]
  }
  #checkov:skip=CKV2_AWS_48: Don't want to pay for Config to support all resources Enable it above if desired
}

resource "aws_config_configuration_recorder_status" "config_rec_stat" {
  name       = aws_config_configuration_recorder.config_rec.name
  is_enabled = true
  depends_on = [var.config_delivery_channel]

  #checkov:skip=CKV2_AWS_45: Don't want to pay for Config to support all resources Enable it in aws_config_configuration_recorder resource if desired
}

## Rule that enforces prohibited public access for S3 buckets
resource "aws_config_config_rule" "s3_public_access_prohibited" {
  name = "s3-public-access-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
  }

  depends_on = [
    aws_config_configuration_recorder_status.config_rec_stat
  ]
}

### Remediation action to automatically disable S3 public read and write
resource "aws_config_remediation_configuration" "disable_public_s3_access" {
  config_rule_name = aws_config_config_rule.s3_public_access_prohibited.name
  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock"

  parameter {
    name         = "AutomationAssumeRole"
    static_value = var.config_remediation_role_arn
  }
  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true
  maximum_automatic_attempts = 5
  retry_attempt_seconds      = 120

  depends_on = [var.config_ssm_automation_policy_attachment]
}


resource "aws_config_config_rule" "s3_sse_enabled" {
  name = "s3-sse-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [
    aws_config_configuration_recorder_status.config_rec_stat
  ]
}

resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  region                       = var.aws_region
  #checkov:skip=CKV2_AWS_3: This check applies to environments using AWS Organizations, which this one does not
}

resource "aws_guardduty_detector_feature" "features" {
  for_each    = toset(var.guardduty_features)
  detector_id = aws_guardduty_detector.main.id
  name        = each.value
  status      = "ENABLED"

  lifecycle {
    ignore_changes = [
      additional_configuration,
      status
    ]
  }
}

# Create EventBridge Rule for AWS GuardDuty
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-findings"
  description = "Trigger on GuardDuty findings"

  event_pattern = jsonencode({
    source = [
      "aws.guardduty"
    ]
    detail-type = [
      "GuardDuty Finding"
    ]
  })
}

# Create EventBridge Target to send events to (target=SNS)
resource "aws_cloudwatch_event_target" "send_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  arn       = aws_sns_topic.alerts.arn
  target_id = "SendToSNS"
}

resource "aws_securityhub_account" "main" {
  depends_on = [aws_guardduty_detector.main]
}

resource "aws_securityhub_standards_subscription" "standards" {
  for_each      = local.securityhub_standards
  standards_arn = each.value
  depends_on    = [aws_securityhub_account.main]
}

# Policies

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
  policy    = var.cloudtrail_sns_to_sqs_json
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