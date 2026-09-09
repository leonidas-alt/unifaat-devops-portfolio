# =============================================
# Aula 03 — Terraform + IAM | TechNova
# Aluno: Emilly Santos de Oliveira (RA: 4023575)
# =============================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
