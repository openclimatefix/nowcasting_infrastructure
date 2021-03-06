output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnets" {
  value = aws_subnet.public_subnet
}

output "private_subnet_group" {
  value = aws_db_subnet_group.private_subnet_group
}
