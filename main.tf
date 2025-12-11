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
  kms_key_arn                               = module.kms.kms_key_arn
  kms_replica_key_arn                       = module.kms.kms_replica_secondary_region_key_arn
  alerts_sns_topic_arn                      = module.monitoring.alerts_sns_topic_arn
  centralized_logs_bucket                   = module.logging.centralized_logs_bucket
  ec2_isolation_dlq_arn                     = module.lambda.ec2_isolation_dlq_arn
  ec2_autostop_dlq_arn                      = module.lambda.ec2_autostop_dlq_arn
  ip_enrich_dlq_arn                         = module.lambda.ip_enrich_dlq_arn
  cloudtrail_log_delivery_arn               = module.monitoring.cloudtrail_log_delivery_arn
  cloudtrail_notifications_arn              = module.monitoring.cloudtrail_notifications_arn
  gen_purp_bucket_notifications_arn         = aws_sns_topic.general_purpose_bucket_notifications.arn
  centralized_logs_bucket_notifications_arn = module.logging.sns_centralized_logs_notifications_arn
  gen_purp_s3_event_queue_arn               = aws_sqs_queue.general_purpose_s3_event_queue.arn
  centralized_logs_s3_event_queue_arn       = module.logging.sqs_centralized_logs_event_queue_arn
  centralized_logs_bucket_arn               = module.logging.centralized_logs_bucket_arn
  gen_purp_bucket_arn                       = aws_s3_bucket.general_purpose.arn
  gen_purp_replica_bucket_arn               = module.s3_replication.general_purpose_replica_bucket_arn
  centralized_logs_replica_bucket_arn       = module.s3_replication.centralized_logs_replica_bucket_arn
  cloudtrail_logs_group_arn                 = module.monitoring.cloudtrail_logs_group_arn
}

module "endpoints" {
  source                 = "./modules/endpoints"
  aws_region             = var.aws_region
  vpc_id                 = module.network.vpc_id
  lambda_subnet_id       = module.network.lambda_subnet_id
  lambda_sub_cidr        = module.network.lambda_sub_cidr
  private_route_table_id = module.network.private_route_table_id
}

module "logging" {
  source                                        = "./modules/logging"
  environment                                   = var.environment
  random_suffix_hex                             = random_id.random_suffix.hex
  replication_role_arn                          = module.iam.replication_role_arn
  kms_master_key_arn                            = module.kms.kms_key_arn
  centralized_logs_replica_bucket               = module.s3_replication.centralized_logs_replica_bucket
  centralized_logs_replica_bucket_arn           = module.s3_replication.centralized_logs_replica_bucket_arn
  kms_key_arn                                   = module.kms.kms_key_arn
  centralized_logs_topic_policy                 = module.logging.centralized_logs_topic_policy
  centralized_logs_topic_policy_json            = module.iam.centralized_logs_topic_policy_json
  config_configuration_recorder_config_rec      = module.monitoring.config_configuration_recorder_config_rec
  cloudtrail_to_cw_role                         = module.iam.cloudtrail_to_cw_role
  cloudtrail_to_cw_policy                       = module.iam.cloudtrail_to_cw_policy
  cloudtrail_to_cw_role_arn                     = module.iam.cloudtrail_to_cw_role_arn
  cloudtrail_logs_group                         = module.monitoring.cloudtrail_logs_group
  cloudtrail_logs_group_arn                     = module.monitoring.cloudtrail_logs_group_arn
  cloudtrail_notifications_name                 = module.monitoring.cloudtrail_notifications_name
  centralized_logs_replica_bucket_s3_bucket_arn = module.s3_replication.centralized_logs_replica_bucket_s3_bucket_arn
  kms_replica_secondary_region_key_arn          = module.kms.kms_replica_secondary_region_key_arn
  centralized_logs_s3_event_queue_id            = module.logging.centralized_logs_s3_event_queue_id
  centralized_logs_s3_sns_to_sqs_json           = module.iam.centralized_logs_s3_sns_to_sqs_json
  centralized_logs_bucket_notifications_arn     = module.logging.centralized_logs_bucket_notifications_arn
}

module "s3_replication" {
  source = "./modules/s3_replication"
  providers = {
    aws           = aws
    aws.secondary = aws.secondary
  }
  random_suffix_hex    = random_id.random_suffix.hex
  secondary_aws_region = var.secondary_aws_region
  environment          = var.environment
  kms_key_arn          = module.kms.kms_key_arn
}

module "lambda" {
  source                             = "./modules/lambda"
  renotify_after_hours_isolate       = var.renotify_after_hours_isolate
  renotify_after_hours_autostop      = var.renotify_after_hours_autostop
  idle_cpu_threshold                 = var.idle_cpu_threshold
  idle_period_minutes                = var.idle_period_minutes
  abuse_ipdb_api_key                 = var.abuse_ipdb_api_key
  kms_key_arn                        = module.kms.kms_key_arn
  ec2_isolate_lambda_to_sqs_json     = module.iam.ec2_isolate_lambda_to_sqs_json
  ec2_autostop_lambda_to_sqs_json    = module.iam.ec2_autostop_lambda_to_sqs_json
  ip_enrich_lambda_to_sqs_json       = module.iam.ip_enrich_lambda_to_sqs_json
  lambda_subnet_id                   = module.network.lambda_subnet_id
  lambda_ec2_isolation_sg_id         = aws_security_group.lambda_ec2_isolation_sg.id
  lambda_ec2_autostop_sg_id          = aws_security_group.lambda_ec2_autostop_sg.id
  lambda_ip_enrich_sg_id             = aws_security_group.lambda_ip_enrich_sg.id
  ec2_isolate_execution_role_arn     = module.iam.ec2_isolate_execution_role_arn
  quarantine_sg_id                   = aws_security_group.quarantine_sg.id
  sns_topic_alerts_arn               = module.monitoring.sns_topic_alerts_arn
  lambda_ec2_isolate_policy          = module.iam.lambda_ec2_isolate_policy
  lambda_autostop_execution_role_arn = module.iam.lambda_autostop_execution_role_arn
  lambda_ip_enrich_arn               = module.iam.lambda_ip_enrich_arn
}

module "kms" {
  source                           = "./modules/kms"
  lambda_ec2_isolate_exec_role_arn = module.iam.lambda_ec2_isolate_execution_role_arn
  lambda_ip_enrich_arn             = module.iam.lambda_ip_enrich_arn
  environment                      = var.environment
  replication_role_arn             = module.iam.replication_role_arn

  providers = {
    aws           = aws
    aws.secondary = aws.secondary
  }
}

module "monitoring" {
  source             = "./modules/monitoring"
  aws_region         = var.aws_region
  environment        = var.environment
  alert_emails       = var.alert_emails
  guardduty_features = var.guardduty_features
  kms_key_arn        = module.kms.kms_key_arn
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
    security_groups = [module.endpoints.vpc_endpoints_sg_id]
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
    security_groups = [module.endpoints.vpc_endpoints_sg_id]
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
      kms_master_key_id = module.kms.kms_key_arn
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

  target_bucket = module.logging.centralized_logs_bucket
  target_prefix = "s3-access-logs/${aws_s3_bucket.general_purpose.bucket}/"
}

### CRR Configuration for General Purpose S3 bucket
resource "aws_s3_bucket_replication_configuration" "general_purpose_replication" {
  bucket = aws_s3_bucket.general_purpose.bucket
  role   = module.iam.replication_role_arn

  depends_on = [module.s3_replication.general_purpose_replica_bucket]

  rule {
    id     = "general-purpose-crr"
    status = "Enabled"

    destination {
      bucket        = module.s3_replication.general_purpose_replica_bucket_arn
      storage_class = "STANDARD_IA"
      encryption_configuration {
        replica_kms_key_id = module.kms.kms_replica_secondary_region_key_arn
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