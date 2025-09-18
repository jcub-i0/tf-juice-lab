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