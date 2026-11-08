# ──────────────────────────────────────────────────────────────────────────────
# outputs.tf — Valores de saída após apply
# Aula 10: Terraform GitOps + CD Pipeline
# ──────────────────────────────────────────────────────────────────────────────

output "ec2_public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.api.public_ip
}

output "ec2_public_dns" {
  description = "DNS público da instância EC2"
  value       = aws_instance.api.public_dns
}

output "ec2_instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.api.id
}

output "ecr_repository_url" {
  description = "URL completa do repositório ECR"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_name" {
  description = "Nome do repositório ECR"
  value       = aws_ecr_repository.api.name
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "api_url" {
  description = "URL da API após deploy"
  value       = "http://${aws_instance.api.public_ip}:3000"
}

output "health_check_url" {
  description = "URL do health check da API"
  value       = "http://${aws_instance.api.public_ip}:3000/health"
}

output "aws_account_id" {
  description = "AWS Account ID (útil para montar URIs do ECR)"
  value       = data.aws_caller_identity.current.account_id
}

output "ssh_command" {
  description = "Comando SSH para acessar a EC2"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${aws_instance.api.public_ip}"
}
