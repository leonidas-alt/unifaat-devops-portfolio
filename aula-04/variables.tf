# =============================================
# variables.tf — Aula 04: VPC + EC2 Multi-AZ
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ── Identificação ─────────────────────────────

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "TechNova"
}

variable "environment" {
  description = "Ambiente de deploy (development, staging, production)"
  type        = string
  default     = "development"
}

variable "aluno" {
  description = "Nome completo do aluno"
  type        = string
  default     = "Emilly Santos de Oliveira"
}

variable "ra" {
  description = "Número de matrícula (RA) do aluno"
  type        = string
  default     = "4023575"
}

# ── AWS ───────────────────────────────────────

variable "aws_region" {
  description = "Região AWS onde a infraestrutura será criada"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Lista com as duas Availability Zones usadas no projeto"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── VPC e Rede ────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block da VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas (uma por AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas (uma por AZ)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.4.0/24"]
}

# ── EC2 ───────────────────────────────────────

variable "instance_type" {
  description = "Tipo de instância EC2 (Free Tier: t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Nome do Key Pair que será criado para acesso SSH"
  type        = string
  default     = "technova-key"
}

variable "api_port" {
  description = "Porta em que a API Node.js escuta"
  type        = number
  default     = 3000
}
