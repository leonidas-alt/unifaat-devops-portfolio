# =============================================
# providers.tf — Aula 04: VPC + EC2 Multi-AZ
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

terraform {
  required_version = ">= 1.0"

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
    }
  }
}
