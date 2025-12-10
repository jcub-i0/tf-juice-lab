output "alerts_sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "cloudtrail_log_delivery_arn" {
  value = aws_sqs_queue.cloudtrail_log_delivery.arn
}

output "cloudtrail_notifications_arn" {
  value = aws_sns_topic.cloudtrail_notifications.arn
}

output "cloudtrail_logs_group" {
  value = aws_cloudwatch_log_group.cloudtrail_logs
}

output "cloudtrail_logs_group_arn" {
  value = aws_cloudwatch_log_group.cloudtrail_logs.arn
}

output "config_configuration_recorder_config_rec" {
  value = aws_config_configuration_recorder.config_rec
}
