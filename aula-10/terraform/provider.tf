# ──────────────────────────────────────────────────────────────────────────────
# provider.tf — Provider AWS + Backend S3
# Aula 10: Terraform GitOps + CD Pipeline
# Aluno: Emilly Santos de Oliveira (RA: 4023575)
#
# NOTA (Learner Lab): O backend S3 requer um bucket pré-existente.
# Crie o bucket manualmente antes do primeiro `terraform init`:
#   aws s3api create-bucket --bucket technova-tfstate-4023575 --region us-east-1
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto: estado armazenado no S3
  # Substitua o bucket pelo nome real criado no Learner Lab
  backend "s3" {
    bucket         = "technova-tfstate-4023575"
    key            = "aula-10/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TechNova"
      ManagedBy   = "terraform"
      Environment = var.environment
      Aluno       = "Emilly Santos de Oliveira"
      RA          = "4023575"
      Aula        = "aula-10"
    }
  }
}
