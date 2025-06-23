# CREATE MONITORING/SECURITY RESOURCES

## Create 8 random digits to tack onto the end of the centralized_logs bucket's name
resource "random_id" "logs_bucket_suffix" {
  byte_length = 2
}

resource "aws_s3_bucket" "centralized_logs" {
  bucket        = "juice-shop-logs-${random_id.logs_bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "Juice Shop Logs"
    Environment = var.environment
  }
}

## Enable SSE encryption on centralized_logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_bucket_encrypt" {
  bucket = aws_s3_bucket.centralized_logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs_bucket" {
  bucket = aws_s3_bucket.centralized_logs.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudtrail" "cloudtrail" {
  depends_on = [
    aws_s3_bucket_policy.cloudtrail_policy,
    aws_iam_role.cloudtrail_to_cw,
    aws_iam_role_policy.cloudtrail_to_cw_policy,
    aws_cloudwatch_log_group.cloudtrail_logs
  ]

  name                          = "CloudTrail"
  s3_bucket_name                = aws_s3_bucket.centralized_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cw.arn

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }
}

resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "tf-juice-lab-cloudtrail"
  retention_in_days = 30

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
  name = "tf-juice-lab-alerts"
}

## Consider using a for_each loop for multiple email addresses to be used
resource "aws_sns_topic_subscription" "alerts_sub" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_config_configuration_recorder" "config_rec" {
  name     = "TF-Juice-Lab-Config"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "config_delivery_channel" {
  name           = "Config-Delivery-Channel"
  s3_bucket_name = aws_s3_bucket.centralized_logs.bucket
  depends_on     = [aws_config_configuration_recorder.config_rec]
}

resource "aws_config_configuration_recorder_status" "config_rec_stat" {
  name       = aws_config_configuration_recorder.config_rec.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.config_delivery_channel]
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
    static_value = aws_iam_role.config_remediation_role.arn
  }
  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true
  maximum_automatic_attempts = 5
  retry_attempt_seconds      = 120

  depends_on = [aws_iam_role_policy_attachment.config_ssm_automation]
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
  enable = true
}

resource "aws_guardduty_detector_feature" "features" {
  for_each    = toset(var.guardduty_features)
  detector_id = aws_guardduty_detector.main.id
  name        = each.value
  status      = "ENABLED"
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

resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "standards" {
  for_each = local.securityhub_standards
  standards_arn = each.value
  depends_on = [aws_securityhub_account.main]
}