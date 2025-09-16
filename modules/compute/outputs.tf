# Instance IDs

output "bastion_id" {
  value = aws_instance.bastion.id
}

output "kali_id" {
  value = aws_instance.kali.id
}

output "juice-shop_id" {
  value = aws_instance.juice-shop.id
}

# Private/Public IPs

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "kali_private_ip" {
  value = aws_instance.kali.private_ip
}

output "juice_private_ip" {
  value = aws_instance.juice-shop.private_ip
}

# Security Group IDs

output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "kali_sg_id" {
  value = aws_security_group.kali_sg.id
}

output "juice_sg_id" {
  value = aws_security_group.juice_sg.id
}

# Key pair names

output "bastion_key_name" {
  value = aws_key_pair.bastion_key.key_name
}

output "kali_key_name" {
  value = aws_key_pair.kali_key.key_name
}

output "juice_key_name" {
  value = aws_key_pair.juice_key.key_name
}

# SSM IAM instance profile

output "ssm_instance_profile" {
  value = aws_iam_instance_profile.ssm_profile.name
}