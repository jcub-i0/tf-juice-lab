output "current_region" {
  value = var.aws_region
}

output "kali_private_ip" {
  value = aws_instance.kali.private_ip
}

output "juice_private_ip" {
    value = aws_instance.juice-shop.private_ip
}