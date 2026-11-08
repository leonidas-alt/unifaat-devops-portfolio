# ──────────────────────────────────────────────────────────────────────────────
# variables.tf — Variáveis de entrada
# Aula 10: Terraform GitOps + CD Pipeline
# ──────────────────────────────────────────────────────────────────────────────

# ── Identificação ─────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "technova"
}

variable "environment" {
  description = "Ambiente de deploy"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "O ambiente deve ser: development, staging ou production."
  }
}

# ── AWS ───────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "Região AWS (Learner Lab: us-east-1)"
  type        = string
  default     = "us-east-1"
}

# ── Rede ──────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "AZ onde a subnet pública será criada"
  type        = string
  default     = "us-east-1a"
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "Tipo da instância EC2 (Free Tier: t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Nome do Key Pair para acesso SSH à EC2"
  type        = string
  default     = "technova-key-aula10"
}

variable "api_port" {
  description = "Porta da API Node.js"
  type        = number
  default     = 3000
}

# ── ECR ───────────────────────────────────────────────────────────────────────

variable "ecr_repository_name" {
  description = "Nome do repositório ECR"
  type        = string
  default     = "technova-api"
}
