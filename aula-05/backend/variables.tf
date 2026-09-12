# =============================================
# backend/variables.tf — Variáveis do Backend
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

variable "aws_region" {
  description = "Região AWS onde o backend será criado"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente (development, staging, production)"
  type        = string
  default     = "development"
}

variable "ra" {
  description = "Número de matrícula (RA) — compõe o nome único do bucket"
  type        = string
  default     = "4023575"
}

variable "bucket_prefix" {
  description = "Prefixo do nome do bucket S3 para o remote state"
  type        = string
  default     = "technova-tfstate"
}

variable "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB usada para state locking"
  type        = string
  default     = "technova-terraform-lock"
}
