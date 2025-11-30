output "general_purpose_replica_bucket_id" {
  value = module.general_purpose_replica_bucket.s3_bucket_id
}

output "general_purpose_replica_bucket_arn" {
  value = module.general_purpose_replica_bucket.s3_bucket_arn
}

output "centralized_logs_replica_bucket_id" {
  value = module.centralized_logs_replica_bucket.s3_bucket_id
}

output "centralized_logs_replica_bucket_arn" {
  value = module.centralized_logs_replica_bucket.s3_bucket_arn
}