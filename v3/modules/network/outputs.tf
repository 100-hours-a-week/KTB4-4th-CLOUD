output "vpc_id" { value = data.aws_vpc.existing.id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "public_subnet_ids" { value = data.aws_subnet.public[*].id }
