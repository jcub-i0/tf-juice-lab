output "ssm_instance_profile_name" {
  value = aws_iam_instance_profile.ssm_profile.name
}

output "replication_role_arn" {
  value = aws_iam_role.replication_role.arn
}

output "lambda_ec2_isolate_execution_role_arn" {
  value = aws_iam_role.lambda_ec2_isolate_execution_role.arn
}

output "lambda_autostop_execution_role_arn" {
  value = aws_iam_role.lambda_autostop_execution_role.arn
}

output "lambda_ip_enrich_arn" {
  value = aws_iam_role.lambda_ip_enrich.arn
}

output "gen_purp_s3_sns_to_sqs_json" {
  value = data.aws_iam_policy_document.gen_purp_s3_sns_to_sqs.json
}

output "general_purpose_sns_policy_json" {
  value = data.aws_iam_policy_document.general_purpose_sns_policy.json
}

output "centralized_logs_topic_policy_json" {
  value = data.aws_iam_policy_document.centralized_logs_sns_policy.json
}

output "centralized_logs_s3_sns_to_sqs_json" {
  value = data.aws_iam_policy_document.centralized_logs_s3_sns_to_sqs.json
}

output "cloudtrail_sns_sqs_json" {
  value = data.aws_iam_policy_document.cloudtrail_sns_to_sqs.json
}

output "ec2_isolate_lambda_to_sqs_json" {
  value = data.aws_iam_policy_document.ec2_isolate_lambda_to_sqs.json
}

output "ec2_autostop_lambda_to_sqs_json" {
  value = data.aws_iam_policy_document.ec2_autostop_lambda_to_sqs.json
}

output "ip_enrich_lambda_to_sqs_json" {
  value = data.aws_iam_policy_document.ip_enrich_lambda_to_sqs.json
}

output "vpc_flow_logs_arn" {
  value = aws_iam_role.vpc_flow_logs.arn
}

output "cloudtrail_to_cw_role" {
  value = aws_iam_role.cloudtrail_to_cw
}

output "cloudtrail_to_cw_role_arn" {
  value = aws_iam_role.cloudtrail_to_cw.arn
}

output "cloudtrail_to_cw_policy" {
  value = aws_iam_role_policy.cloudtrail_to_cw_policy
}

output "config_remediation_role_arn" {
  value = aws_iam_role.config_remediation_role.arn
}

output "ec2_isolate_execution_role_arn" {
  value = aws_iam_role.lambda_ec2_isolate_execution_role.arn
}

output "lambda_ec2_isolate_policy" {
  value = aws_iam_role_policy.lambda_ec2_isolate_policy
}

output "config_role_arn" {
  value = module.iam.config_role_arn
}