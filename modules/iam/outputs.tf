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