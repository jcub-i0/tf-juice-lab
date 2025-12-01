output "current_region" {
  value = var.aws_region
}

output "bastion_public_ip" {
  value = module.compute.bastion_public_ip
}

output "kali_private_ip" {
  value = module.compute.kali_private_ip
}

output "juice_private_ip" {
  value = module.compute.juice_private_ip
}

output "enabled_securityhub_standards" {
  value = {
    for key, value in aws_securityhub_standards_subscription.standards :
    key => value.standards_arn
  }
}

output "general_purpose_s3_bucket_name" {
  value = aws_s3_bucket.general_purpose.bucket
}

output "centralized_logs_s3_bucket_name" {
  value = module.logging.centralized_logs_bucket
}

output "kms_key_arn" {
  description = "KMS Key ARN used for CloudTrail, SNS, etc."
  value       = module.kms.kms_key_arn
}