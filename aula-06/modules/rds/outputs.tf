# modules/rds/outputs.tf

output "db_endpoint" {
  description = "Endpoint de conexão com o banco de dados"
  value       = aws_db_instance.this.endpoint
}

output "db_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.this.db_name
}

output "db_port" {
  description = "Porta do banco de dados"
  value       = aws_db_instance.this.port
}
