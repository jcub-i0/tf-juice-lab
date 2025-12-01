output "centralized_logs_bucket" {
  value = aws_s3_bucket.centralized_logs.bucket
}

output "centralized_logs_bucket_arn" {
  value = aws_s3_bucket.centralized_logs.arn
}

output "sns_centralized_logs_notifications_arn" {
  value = aws_sns_topic.centralized_logs_bucket_notifications.arn
}

output "sqs_centralized_logs_event_queue_arn" {
  value = aws_sqs_queue.centralized_logs_s3_event_queue.arn
}

output "config_delivery_channel" {
  value = aws_config_delivery_channel.config_delivery_channel
}

output "centralized_logs_s3_event_queue_id" {
  value = aws_sqs_queue.centralized_logs_s3_event_queue.id
}

output "centralized_logs_bucket_notifications_arn" {
  value = aws_sns_topic.centralized_logs_bucket_notifications.arn
}