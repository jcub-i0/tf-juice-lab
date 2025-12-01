output "kms_key_arn" {
  value = module.kms.key_arn
}

output "kms_replica_secondary_region_key_arn" {
  value = module.kms_replica_secondary_region.key_arn
}