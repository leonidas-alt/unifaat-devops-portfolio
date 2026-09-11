# =============================================
# outputs.tf — Outputs da Infraestrutura Aula 04
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ── VPC ───────────────────────────────────────

output "vpc_id" {
  description = "ID da VPC principal da TechNova"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block da VPC"
  value       = aws_vpc.main.cidr_block
}

# ── Subnets ───────────────────────────────────

output "public_subnet_ids" {
  description = "Lista com os IDs das subnets públicas (AZ-a e AZ-b)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Lista com os IDs das subnets privadas (AZ-a e AZ-b)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas"
  value       = aws_subnet.private[*].cidr_block
}

# ── Internet Gateway ──────────────────────────

output "internet_gateway_id" {
  description = "ID do Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# ── Security Groups ───────────────────────────

output "api_security_group_id" {
  description = "ID do Security Group da API (portas 22 e 3000)"
  value       = aws_security_group.api.id
}

output "db_security_group_id" {
  description = "ID do Security Group do banco de dados (PostgreSQL 5432 interno)"
  value       = aws_security_group.db.id
}

# ── IAM ───────────────────────────────────────
# Nota: AWS Academy bloqueia iam:CreateRole — outputs comentados para o lab.
# O código em iam.tf está correto e seria aplicado em conta com permissão plena.

# output "iam_role_arn" {
#   description = "ARN da IAM Role do EC2"
#   value       = aws_iam_role.ec2_role.arn
# }
#
# output "instance_profile_name" {
#   description = "Nome do Instance Profile anexado ao EC2"
#   value       = aws_iam_instance_profile.ec2_profile.name
# }

# ── EC2 ───────────────────────────────────────

output "ec2_instance_id" {
  description = "ID da instância EC2 da API"
  value       = aws_instance.api.id
}

output "ec2_public_ip" {
  description = "IP público da instância EC2 (use para curl e SSH)"
  value       = aws_instance.api.public_ip
}

output "ec2_private_ip" {
  description = "IP privado da instância EC2"
  value       = aws_instance.api.private_ip
}

output "ec2_availability_zone" {
  description = "Availability Zone onde a instância foi provisionada"
  value       = aws_instance.api.availability_zone
}

output "ami_id" {
  description = "ID da AMI Amazon Linux 2023 utilizada"
  value       = data.aws_ami.amazon_linux_2023.id
}

# ── Conexão e Acesso ──────────────────────────

output "api_url" {
  description = "URL completa para acessar a API TechNova"
  value       = "http://${aws_instance.api.public_ip}:3000"
}

output "api_health_url" {
  description = "URL do endpoint de health check da API"
  value       = "http://${aws_instance.api.public_ip}:3000/health"
}

output "ssh_command" {
  description = "Comando SSH para conectar à instância EC2"
  value       = "ssh -i ${path.module}/technova-key.pem ec2-user@${aws_instance.api.public_ip}"
}

output "key_pair_name" {
  description = "Nome do Key Pair criado na AWS"
  value       = aws_key_pair.technova.key_name
}

output "private_key_path" {
  description = "Caminho local para a chave privada .pem"
  value       = local_sensitive_file.private_key.filename
  sensitive   = true
}
