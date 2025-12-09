# Lambda resources

## Lambda EC2 Isolation
### Lambda function to perform EC2 isolation, tag EC2 resource(s) with MITRE TTP, and snapshot EBS volumes before quarantine
resource "aws_lambda_function" "ec2_isolation" {
  function_name    = "ec2_isolation"
  description      = "Isolate compromised EC2 instance by placing it in Quarantine SG"
  filename         = data.archive_file.lambda_ec2_isolate_zip.output_path
  handler          = "ec2_isolate_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_ec2_isolate_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [module.network.lambda_subnet_id]
    security_group_ids = [aws_security_group.lambda_ec2_isolation_sg.id]
  }

  reserved_concurrent_executions = 5
  kms_key_arn                    = var.kms_key_arn

  # Enable X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.ec2_isolation_dlq.arn
  }

  runtime = "python3.12"
  role    = module.iam.ec2_isolate_execution_role_arn

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

  depends_on = [
    module.iam.lambda_ec2_isolate_policy,
    aws_sqs_queue_policy.ec2_isolate_dlq_policy
  ]
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

### SQS DLQ for EC2 Isolation Lambda
resource "aws_sqs_queue" "ec2_isolation_dlq" {
  name              = "ec2-isolation-lambda-dlq"
  kms_master_key_id = var.kms_key_arn
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
  kms_key_arn                    = var.kms_key_arn

  vpc_config {
    subnet_ids         = [module.network.lambda_subnet_id]
    security_group_ids = [aws_security_group.lambda_ec2_autostop_sg.id]
  }

  depends_on = [
    aws_sqs_queue_policy.ec2_autostop_lambda_to_sqs
  ]

  # Enable X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.ec2_autostop_dlq.arn
  }

  runtime = "python3.12"
  role    = module.iam.lambda_autostop_execution_role_arn

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

### SQS DLQ for EC2 AutoStop Lambda
resource "aws_sqs_queue" "ec2_autostop_dlq" {
  name              = "ec2-autostop-lambda-dlq"
  kms_master_key_id = var.kms_key_arn
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
  role             = module.iam.lambda_ip_enrich_arn
  handler          = "ip_enrich_function.lambda_handler"
  source_code_hash = data.archive_file.ip_enrich.output_base64sha256
  runtime          = "python3.12"

  reserved_concurrent_executions = 10
  kms_key_arn                    = var.kms_key_arn

  depends_on = [
    aws_sqs_queue_policy.ip_enrich_lambda_to_sqs
  ]

  vpc_config {
    subnet_ids         = [module.network.lambda_subnet_id]
    security_group_ids = [aws_security_group.lambda_ip_enrich_sg.id]
  }

  # Enable X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.ip_enrich_dlq.arn
  }

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

### EventBridge Target to send events to (target=SNS)
resource "aws_cloudwatch_event_target" "securityhub_finding_event_target_ip_enrich" {
  rule      = aws_cloudwatch_event_rule.securityhub_finding_event.name
  target_id = "trigger-ip-enrich-lambda"
  arn       = aws_lambda_function.ip_enrich.arn
}

### SQS DLQ for EC2 IP Enrichment Lambda
resource "aws_sqs_queue" "ip_enrich_dlq" {
  name              = "ec2-ip-enrich-lambda-dlq"
  kms_master_key_id = var.kms_key_arn
}

## Lambda-related permissions
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