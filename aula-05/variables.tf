# =============================================
# variables.tf - Aula 05: RDS + Remote State
# TechNova - Emilly Santos de Oliveira (4023575)
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

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública (onde a EC2 ficará)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "CIDRs das 2 subnets privadas em AZs diferentes (DB Subnet Group)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24"]
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
  default     = "technova-key-aula05"
}

variable "api_port" {
  description = "Porta da API Node.js (usada no Security Group)"
  type        = number
  default     = 3000
}

# ── RDS ───────────────────────────────────────

variable "db_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
  default     = "technova_db"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_name))
    error_message = "O nome do banco deve começar com letra e ter no máximo 63 caracteres."
  }
}

variable "db_username" {
  description = "Username master do banco de dados RDS"
  type        = string
  default     = "technova_admin"
  sensitive   = true

  validation {
    condition     = !contains(["admin", "postgres", "root", "master"], var.db_username)
    error_message = "Use um username diferente dos valores reservados (admin, postgres, root, master)."
  }
}

variable "db_password" {
  description = "Senha master do banco de dados RDS - mínimo 16 caracteres"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 16
    error_message = "A senha do banco deve ter no mínimo 16 caracteres."
  }
}

variable "db_instance_class" {
  description = "Classe de instância do RDS (Free Tier: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "15"
}

variable "db_allocated_storage" {
  description = "Tamanho do disco em GB"
  type        = number
  default     = 20
}

variable "db_port" {
  description = "Porta do PostgreSQL"
  type        = number
  default     = 5432
}
