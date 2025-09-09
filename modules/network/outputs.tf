output "vpc_id" {
  value = aws_vpc.tf-juice-lab.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "lambda_subnet_id" {
  value = aws_subnet.lambda_private.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "lambda_route_table_id" {
    value = aws_route_table.lambda.id
}

output "natgw_id" {
  value = aws_nat_gateway.natgw.id
}

output "igw_id" {
  value = aws_internet_gateway.igw.id
}

output "lambda_sub_cidr" {
  value = aws_subnet.lambda_private.cidr_block
}