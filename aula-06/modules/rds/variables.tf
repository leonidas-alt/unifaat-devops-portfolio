# modules/rds/variables.tf

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "db_username" {
  description = "Usuário master do banco de dados"
  type        = string
}

variable "db_password" {
  description = "Senha master do banco de dados"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Lista de IDs das subnets para o DB Subnet Group (use subnets privadas)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Lista de IDs dos Security Groups associados ao RDS"
  type        = list(string)
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}
