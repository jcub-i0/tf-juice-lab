# Create SNS topic for S3 event notifications
resource "aws_sns_topic" "general_purpose_bucket_notifications" {
  name              = "general-purpose-s3-notifications"
  kms_master_key_id = module.kms.kms_key_arn
}

resource "aws_s3_bucket_notification" "general_purpose" {
  bucket = aws_s3_bucket.general_purpose.bucket

  topic {
    topic_arn     = aws_sns_topic.general_purpose_bucket_notifications.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "logs/"
  }

  depends_on = [
    aws_s3_bucket.general_purpose,
    aws_sns_topic.general_purpose_bucket_notifications,
    aws_sns_topic_policy.general_purpose_topic_policy
  ]
}

resource "aws_sqs_queue" "general_purpose_s3_event_queue" {
  name              = "general-purpose-s3-events"
  kms_master_key_id = module.kms.kms_key_arn
}

resource "aws_sns_topic_subscription" "general_purpose_bucket_notifications_sub" {
  topic_arn = aws_sns_topic.general_purpose_bucket_notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.general_purpose_s3_event_queue.arn
}
