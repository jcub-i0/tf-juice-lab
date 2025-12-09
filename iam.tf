# CREATE AND ATTACH IAM ROLES, INSTANCE PROFILES, ETC

# S3 Bucket Policies

## S3 bucket policy to allow Lambda EC2 Isolation func and the Terraform admin user read access to the General Purpose S3 bucket
resource "aws_s3_bucket_policy" "general_purpose_policy" {
  bucket = aws_s3_bucket.general_purpose.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Allow EC2 Isolation Lambda func access to General Purpose S3 bucket"
        Effect = "Allow",
        Principal = {
          AWS = [
            module.iam.lambda_ec2_isolate_execution_role_arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.terraform_admin_username}"
          ]
        },
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = "${aws_s3_bucket.general_purpose.arn}/*"
      },
      {
        Sid    = "AllowReplicationRoleReadFromSource"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.replication_role_arn
        }
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectLegalHold",
          "s3:GetObjectRetention",
          "s3:GetObjectTagging",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = [
          aws_s3_bucket.general_purpose.arn,
          "${aws_s3_bucket.general_purpose.arn}/*"
        ]
      }
    ]
  })
}

### Attach IAM policy that allows General Purpose S3 Notifications SNS to send messages to SQS
resource "aws_sqs_queue_policy" "gen_purp_s3_sns_to_sqs" {
  queue_url = aws_sqs_queue.general_purpose_s3_event_queue.id
  policy    = module.iam.gen_purp_s3_sns_to_sqs_json
}

resource "aws_s3_bucket_policy" "general_purpose_replica_policy" {
  provider = aws.secondary
  bucket   = module.s3_replication.general_purpose_replica_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReplicationRoleWriteToReplica"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.replication_role_arn
        }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [
          module.s3_replication.general_purpose_replica_bucket_arn,
          "${module.s3_replication.general_purpose_replica_bucket_arn}/*"
        ]
      }
    ]
  })
}