
# S3 Modules for S3 CRR
## General Purpose Replica
module "general_purpose_replica_bucket" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=2a25737a72c7e862ea297cea063207a3aa56b1a8"

  bucket = "general-purpose-replica-${random_id.random_suffix.hex}"
  region = var.secondary_aws_region

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms.key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  logging = {
    target_bucket = module.centralized_logs_replica_bucket.s3_bucket_id
    target_prefix = "log/general-purpose-replica/"
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = {
    Name        = "General Purpose Replica"
    Environment = var.environment
    Purpose     = "Cross-Region Replication destination for General Purpose S3"
  }
}

## Centralized Logs Replica
module "centralized_logs_replica_bucket" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=2a25737a72c7e862ea297cea063207a3aa56b1a8"

  bucket = "centralized-logs-replica-${random_id.random_suffix.hex}"
  region = var.secondary_aws_region

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = module.kms.key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = {
    Name        = "Centralized Logs Replica"
    Environment = var.environment
    Purpose     = "Cross-Region Replication destination bucket for Centralized Logs S3"
  }
}