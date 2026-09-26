# modules/vpc/outputs.tf

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Lista de IDs das subnets públicas"
  value = [
    for key, subnet in aws_subnet.this : subnet.id
    if var.subnets[key].type == "public"
  ]
}

output "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas"
  value = [
    for key, subnet in aws_subnet.this : subnet.id
    if var.subnets[key].type == "private"
  ]
}

output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.main.id
}
