module "network" {
  source           = "./modules/network"
  vpc_cidr         = var.vpc_cidr
  public_sub_cidr  = var.public_sub_cidr
  public_sub_az    = var.public_sub_az
  private_sub_cidr = var.private_sub_cidr
  private_sub_az   = var.private_sub_az
  lambda_sub_cidr  = var.lambda_sub_cidr
  lambda_sub_az    = var.lambda_sub_az
}

module "compute" {
  source                    = "./modules/compute"
  vpc_id                    = module.network.vpc_id
  public_subnet_id          = module.network.public_subnet_id
  private_subnet_id         = module.network.private_subnet_id
  private_sub_cidr          = var.private_sub_cidr
  bastion_allowed_cidrs     = var.bastion_allowed_cidrs
  ssm_instance_profile_name = module.iam.ssm_instance_profile_name
}

module "iam" {
  source                                    = "./modules/iam"
  terraform_admin_username                  = var.terraform_admin_username
  account_id                                = var.account_id
  general_purpose_bucket_arn                = aws_s3_bucket.general_purpose.arn
  kms_key_arn                               = module.kms.key_arn
  kms_replica_key_arn                       = module.kms_replica_secondary_region.key_arn
  alerts_sns_topic_arn                      = aws_sns_topic.alerts.arn
  centralized_logs_bucket                   = aws_s3_bucket.centralized_logs.bucket
  ec2_isolation_dlq_arn                     = aws_sqs_queue.ec2_isolation_dlq.arn
  ec2_autostop_dlq_arn                      = aws_sqs_queue.ec2_autostop_dlq.arn
  ip_enrich_dlq_arn                         = aws_sqs_queue.ip_enrich_dlq.arn
  cloudtrail_log_delivery_arn               = aws_sqs_queue.cloudtrail_log_delivery.arn
  cloudtrail_notifications_arn              = aws_sns_topic.cloudtrail_notifications.arn
  gen_purp_bucket_notifications_arn         = aws_sns_topic.general_purpose_bucket_notifications.arn
  centralized_logs_bucket_notifications_arn = aws_sns_topic.centralized_logs_bucket_notifications.arn
  gen_purp_s3_event_queue_arn               = aws_sqs_queue.general_purpose_s3_event_queue.arn
  centralized_logs_s3_event_queue_arn       = aws_sqs_queue.centralized_logs_s3_event_queue.arn
  centralized_logs_bucket_arn               = aws_s3_bucket.centralized_logs.arn
  gen_purp_bucket_arn                       = aws_s3_bucket.general_purpose.arn
  gen_purp_replica_bucket_arn               = module.general_purpose_replica_bucket.s3_bucket_arn
  centralized_logs_replica_bucket_arn       = module.centralized_logs_replica_bucket.s3_bucket_arn
  cloudtrail_log_group_arn                  = aws_cloudwatch_log_group.cloudtrail_logs.arn
}

resource "aws_security_group" "quarantine_sg" {
  name        = "quarantine-sg"
  description = "Security Group to send compromised EC2 instances to for isolation"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow only HTTPS for SSM"
  }

  tags = {
    Name = "quarantine_sg"
  }
}

resource "aws_security_group" "lambda_ec2_isolation_sg" {
  name        = "lambda-ec2-isolation-sg"
  description = "Security Group for EC2 Isolation Lambda function"
  vpc_id      = module.network.vpc_id

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints_sg.id]
    description     = "Allow Lambda EC2 Isolation function to only communicate with VPC endpoints inside main VPC"
  }

  tags = {
    Name = "lambda_ec2_isolation"
  }
}

resource "aws_security_group" "lambda_ec2_autostop_sg" {
  name        = "lambda-ec2-autostop-sg"
  description = "Security Group for EC2 Autostop function"
  vpc_id      = module.network.vpc_id

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints_sg.id]
    description     = "Allow Lambda EC2 Autostop function to only communicate with VPC endpoints inside main VPC"
  }

  tags = {
    Name = "lambda_ec2_autostop"
  }
}

resource "aws_security_group" "lambda_ip_enrich_sg" {
  name        = "lambda-ip-enrich-sg"
  description = "Security Group for IP Enrichment Lambda function"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Lambda IP Enrichment to reach out to AbuseIPDB for IP address data"
  }

  tags = {
    Name = "lambda_ip_enrichment"
  }
}

# Security Group for all VPC endpoints
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Allow Lambda subnets to talk to AWS services over HTTPS"
  vpc_id      = module.network.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.network.lambda_sub_cidr]
    description = "Allow Lambda functions to communicate with VPC endpoints"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.network.lambda_sub_cidr]
    description = "Allow VPC endpoints to communicate with Lambda functions"
  }

  tags = {
    Name = "vpc_endpoints_sg"
  }
}

## Create 8 random digits to tack onto resources that require a unique name
resource "random_id" "random_suffix" {
  byte_length = 4
}

# General Purpose S3 bucket
resource "aws_s3_bucket" "general_purpose" {
  bucket = "general-purpose-${random_id.random_suffix.hex}"

  tags = {
    Name        = "General Purpose"
    Environment = var.environment
    Purpose     = "Store miscellaneous or shared resources"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "general_purpose_sse" {
  bucket = aws_s3_bucket.general_purpose.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = module.kms.key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "general_purpose_versioning" {
  bucket = aws_s3_bucket.general_purpose.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "general_purpose_lifecycle" {
  depends_on = [aws_s3_bucket_versioning.general_purpose_versioning]

  bucket = aws_s3_bucket.general_purpose.id

  rule {
    id     = "config"
    status = "Enabled"

    expiration {
      days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter {
      prefix = ""
    }
  }
}

resource "aws_s3_bucket_public_access_block" "general_purpose_public_block" {
  bucket = aws_s3_bucket.general_purpose.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_logging" "general_purpose_logging" {
  bucket = aws_s3_bucket.general_purpose.bucket

  target_bucket = aws_s3_bucket.centralized_logs.bucket
  target_prefix = "s3-access-logs/${aws_s3_bucket.general_purpose.bucket}/"
}

### CRR Configuration for General Purpose S3 bucket
resource "aws_s3_bucket_replication_configuration" "general_purpose_replication" {
  bucket = aws_s3_bucket.general_purpose.bucket
  role   = module.iam.replication_role_arn

  depends_on = [module.general_purpose_replica_bucket]

  rule {
    id     = "general-purpose-crr"
    status = "Enabled"

    destination {
      bucket        = module.general_purpose_replica_bucket.s3_bucket_arn
      storage_class = "STANDARD_IA"
      encryption_configuration {
        replica_kms_key_id = module.kms_replica_secondary_region.key_arn
      }
    }

    filter {
      prefix = ""
    }

    source_selection_criteria {
      replica_modifications {
        status = "Enabled"
      }
      sse_kms_encrypted_objects {
        status = "Enabled"

      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}