# =============================================
# outputs.tf - Outputs da Infraestrutura Aula 05
# TechNova - Emilly Santos de Oliveira (4023575)
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

output "public_subnet_id" {
  description = "ID da subnet pública (onde a EC2 está)"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas (onde o RDS está)"
  value       = aws_subnet.private[*].id
}

output "private_subnet_azs" {
  description = "AZs das subnets privadas do RDS"
  value       = aws_subnet.private[*].availability_zone
}

# ── Security Groups ───────────────────────────

output "ec2_security_group_id" {
  description = "ID do Security Group do EC2 (portas 22 e 3000)"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "ID do Security Group do RDS (PostgreSQL porta 5432 do EC2)"
  value       = aws_security_group.rds.id
}

# ── EC2 ───────────────────────────────────────

output "ec2_instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "IP público da EC2 - use para SSH e evidências"
  value       = aws_instance.app.public_ip
}

output "ec2_private_ip" {
  description = "IP privado da EC2"
  value       = aws_instance.app.private_ip
}

output "ec2_availability_zone" {
  description = "AZ onde a EC2 foi provisionada"
  value       = aws_instance.app.availability_zone
}

output "ssh_command" {
  description = "Comando SSH para acessar a EC2"
  value       = "ssh -i ${path.module}/technova-key.pem ec2-user@${aws_instance.app.public_ip}"
}

output "private_key_path" {
  description = "Caminho da chave privada .pem"
  value       = local_sensitive_file.private_key.filename
  sensitive   = true
}

# ── RDS ───────────────────────────────────────

output "rds_endpoint" {
  description = "Endpoint completo do RDS (host:porta) - use no psql -h"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "Hostname do RDS (sem porta)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "Porta do PostgreSQL"
  value       = aws_db_instance.postgres.port
}

output "rds_db_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.postgres.db_name
}

output "rds_identifier" {
  description = "Identificador da instância RDS no console AWS"
  value       = aws_db_instance.postgres.identifier
}

output "rds_engine_version" {
  description = "Versão do PostgreSQL em uso"
  value       = aws_db_instance.postgres.engine_version_actual
}

# ── Connection Strings ────────────────────────

output "psql_connection_command" {
  description = "Comando psql para conectar ao RDS a partir da EC2"
  value       = "psql -h ${aws_db_instance.postgres.address} -p ${aws_db_instance.postgres.port} -U ${var.db_username} -d ${var.db_name}"
  sensitive   = true # contém o username
}

output "connection_string" {
  description = "Connection string PostgreSQL (sem senha)"
  value       = "postgresql://${var.db_username}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}"
  sensitive   = true
}

output "rds_test_log_command" {
  description = "Comando para ver o log de conexão automático gerado pelo user_data"
  value       = "ssh -i ${path.module}/technova-key.pem ec2-user@${aws_instance.app.public_ip} 'cat /var/log/rds-test.log'"
}

# ── IAM (desabilitado no AWS Academy) ────────
# output "iam_role_arn" { ... }
# output "instance_profile_name" { ... }

# ── Resumo para o PR ──────────────────────────

output "summary" {
  description = "Resumo da infraestrutura para incluir no entrega.md"
  value       = <<-EOT
    =========================================
    TechNova - Aula 05: RDS + Remote State
    Aluno: ${var.aluno} | RA: ${var.ra}
    =========================================
    VPC:         ${aws_vpc.main.id} (${aws_vpc.main.cidr_block})
    EC2:         ${aws_instance.app.id} - IP: ${aws_instance.app.public_ip}
    RDS:         ${aws_db_instance.postgres.identifier}
    RDS Endpoint: ${aws_db_instance.postgres.address}
    -----------------------------------------
    SSH: ssh -i technova-key.pem ec2-user@${aws_instance.app.public_ip}
    Log: ssh acima + 'cat /var/log/rds-test.log'
    =========================================
  EOT
}
