# environments/dev/variables.tf

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "technova"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "key_name" {
  description = "Nome do key pair SSH"
  type        = string
  default     = "technova-key"
}

variable "ami_id" {
  description = "ID da AMI para a instância EC2"
  type        = string
}

variable "db_username" {
  description = "Usuário master do banco de dados"
  type        = string
  default     = "technovaadmin"
}

variable "db_password" {
  description = "Senha master do banco de dados"
  type        = string
  sensitive   = true
}
