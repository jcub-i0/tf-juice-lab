output "ec2_isolation_dlq_arn" {
  value = aws_sqs_queue.ec2_isolation_dlq.arn
}

output "ec2_autostop_dlq_arn" {
  value = aws_sqs_queue.ec2_autostop_dlq.arn
}

output "ip_enrich_dlq_arn" {
  value = aws_sqs_queue.ip_enrich_dlq.arn
}