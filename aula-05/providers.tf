# =============================================
# providers.tf — Aula 05: RDS + Remote State
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================
#
# FLUXO DE EXECUÇÃO:
#   1. cd backend/ && terraform init && terraform apply
#   2. Copie o output "bucket_name" gerado pelo backend
#   3. Substitua SEU-BUCKET-AQUI pelo nome real do bucket
#   4. cd .. && terraform init (inicializa com o backend S3)
#
# ⚠️  O bloco backend "s3" NÃO aceita variáveis ou interpolações.
#     Os valores devem ser literais (hardcoded).
#     Por isso o bucket_name precisa ser copiado manualmente.
# =============================================

terraform {
  required_version = ">= 1.0"

  # ── Remote State: S3 + DynamoDB ──────────────
  # ANTES de executar: cd backend/ && terraform apply
  # Depois substitua SEU-BUCKET-AQUI pelo output "bucket_name".
  # Exemplo: "technova-tfstate-4023575-a1b2c3d4"

  backend "s3" {
    bucket         = "technova-tfstate-4023575-05ebccce"
    key            = "aula-05/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "technova-terraform-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TechNova"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.ra
      Aula        = "05"
    }
  }
}
