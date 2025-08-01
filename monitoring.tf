# CREATE MONITORING/SECURITY RESOURCES

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

resource "aws_s3_bucket" "centralized_logs" {
  bucket = "juice-shop-logs-${random_id.random_suffix.hex}"

  tags = {
    Name        = "Juice Shop Logs"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "centralized_logs_lifecycle" {
  depends_on = [aws_s3_bucket_versioning.logs_bucket]

  bucket = aws_s3_bucket.centralized_logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {
      prefix = ""
    }
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

resource "aws_s3_bucket_public_access_block" "centralized_logs_public_block" {
  bucket = aws_s3_bucket.centralized_logs.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
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
  retention_in_days = 365

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
  name = "tf-juice-lab-security-alerts"
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
    all_supported                 = false
    include_global_resource_types = false

    resource_types = [
      "AWS::EC2::Instance",
      "AWS::S3::Bucket"
    ]
  }
  #checkov:skip=CKV2_AWS_48: Don't want to pay for Config to support all resources Enable it above if desired
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
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  region                       = var.aws_region
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

# Lambda resources

## Lambda EC2 Isolation
### Zip file containing Lambda function code
data "archive_file" "lambda_ec2_isolate_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ec2_isolate/ec2_isolate_function.py"
  output_path = "${path.module}/lambda/ec2_isolate/ec2_isolate_function.zip"
}

### Lambda function to perform EC2 isolation, tag EC2 resource(s) with MITRE TTP, and snapshot EBS volumes before quarantine
resource "aws_lambda_function" "ec2_isolation" {
  function_name    = "ec2_isolation"
  description      = "Isolate compromised EC2 instance by placing it in Quarantine SG"
  filename         = data.archive_file.lambda_ec2_isolate_zip.output_path
  handler          = "ec2_isolate_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_ec2_isolate_zip.output_base64sha256

  reserved_concurrent_executions = 5

  runtime = "python3.12"
  role    = aws_iam_role.lambda_ec2_isolate_execution_role.arn

  #checkov:skip=CKV_AWS_272: source_code_hash is sufficient integrity validation for this environment

  environment {
    variables = {
      QUARANTINE_SG_ID     = aws_security_group.quarantine_sg.id
      RENOTIFY_AFTER_HOURS = var.renotify_after_hours_isolate
      SNS_TOPIC_ARN        = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Name = "EC2IsolationLambda"
  }

  depends_on = [aws_iam_role_policy.lambda_ec2_isolate_policy]
}

### EventBridge Rule to trigger EC2 Isolation Lambda function
resource "aws_cloudwatch_event_rule" "securityhub_ec2_isolate" {
  name        = "securityhub-ec2-isolate"
  description = "Isolate EC2 instances with critical findings"

  event_pattern = jsonencode({
    "source" = [
      "aws.securityhub"
    ],
    "detail-type" = [
      "Security Hub Findings - Imported"
    ],
    "detail" = {
      "findings" = {
        "Severity" = {
          "Label" = ["HIGH", "CRITICAL"]
        },
        "Resources" = {
          "Type" = ["AwsEc2Instance"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub_ec2_isolate_target" {
  rule      = aws_cloudwatch_event_rule.securityhub_ec2_isolate.name
  target_id = "isolate-ec2"
  arn       = aws_lambda_function.ec2_isolation.arn
}

## Lambda EC2 Autostop on Idle
### Zip file containing EC2 autostop func code
data "archive_file" "lambda_ec2_autostop_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ec2_autostop/ec2_autostop.py"
  output_path = "${path.module}/lambda/ec2_autostop/ec2_autostop.zip"
}

resource "aws_lambda_function" "ec2_autostop" {
  function_name    = "ec2_autostop"
  description      = "Automatically stop EC2 instance when they have been idle for 60 minutes"
  handler          = "ec2_autostop.lambda_handler"
  filename         = data.archive_file.lambda_ec2_autostop_zip.output_path
  source_code_hash = data.archive_file.lambda_ec2_autostop_zip.output_base64sha256

  reserved_concurrent_executions = 5

  runtime = "python3.12"
  role    = aws_iam_role.lambda_autostop_execution_role.arn

  #checkov:skip=CKV_AWS_272: source_code_hash is sufficient integrity validation for this environment

  environment {
    variables = {
      IDLE_CPU_THRESHOLD   = var.idle_cpu_threshold
      IDLE_PERIOD_MINUTES  = var.idle_period_minutes
      SNS_TOPIC_ARN        = aws_sns_topic.alerts.arn
      RENOTIFY_AFTER_HOURS = var.renotify_after_hours_autostop
    }
  }
}

### EventBridge Rule for Lambda EC2 Autostop
resource "aws_cloudwatch_event_rule" "ec2_autostop_schedule" {
  name                = "ec2-autostop-every-hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "ec2_autostop_target" {
  rule      = aws_cloudwatch_event_rule.ec2_autostop_schedule.name
  target_id = "trigger-autostop-ec2"
  arn       = aws_lambda_function.ec2_autostop.arn
}

## Lambda IP Encrichment function
### Zip file containing Lambda function code
data "archive_file" "ip_enrich" {
  type        = "zip"
  source_file = "${path.module}/lambda/ip_enrich/ip_enrich_function.py"
  output_path = "${path.module}/lambda/ip_enrich/ip_enrich_function.zip"
}

### Create IP Enrichment Lambda function
resource "aws_lambda_function" "ip_enrich" {
  filename         = data.archive_file.ip_enrich.output_path
  description      = "Enrich IP address information by querying AbuseIPDB and include that data in SNS notification"
  function_name    = "ip_enrichment"
  role             = aws_iam_role.lambda_ip_enrich.arn
  handler          = "ip_enrich_function.lambda_handler"
  source_code_hash = data.archive_file.ip_enrich.output_base64sha256
  runtime          = "python3.12"

  reserved_concurrent_executions = 10

  #checkov:skip=CKV_AWS_272: source_code_hash is sufficient integrity validation for this environment

  environment {
    variables = {
      SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
      ABUSE_IPDB_API_KEY = var.abuse_ipdb_api_key
    }
  }
  layers = [
    aws_lambda_layer_version.requests.arn
  ]
}

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/layer"
  output_path = "${path.module}/lambda/layer.zip"
}

### Create Lambda layer so IP Enrichment Lambda can use the requests library
resource "aws_lambda_layer_version" "requests" {
  filename            = data.archive_file.layer.output_path
  layer_name          = "requests"
  compatible_runtimes = ["python3.12"]
  description         = "Layer so Lambda functions can use the 'requests' library"
}

### EventBridge rule that triggers on any Security Hub finding across entire cloud account
resource "aws_cloudwatch_event_rule" "securityhub_finding_event" {
  name        = "SecurityHubFindingEventRule"
  description = "Triggers on new Security Hub findings"

  event_pattern = jsonencode({
    "source"      = ["aws.securityhub"],
    "detail-type" = ["Security Hub Findings - Imported"]
  })
}

resource "aws_cloudwatch_event_target" "securityhub_finding_event_target_ip_enrich" {
  rule      = aws_cloudwatch_event_rule.securityhub_finding_event.name
  target_id = "trigger-ip-enrich-lambda"
  arn       = aws_lambda_function.ip_enrich.arn
}