output "ssm_instance_profile_name" {
  value = aws_iam_instance_profile.ssm_profile.name
}

output "replication_role_arn" {
  value = aws_iam_role.replication_role.arn
}