output "alerts_sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "cloudtrail_log_delivery_arn" {
  value = aws_sqs_queue.cloudtrail_log_delivery.arn
}

output "cloudtrail_notifications_arn" {
  value = aws_sns_topic.cloudtrail_notifications.arn
}