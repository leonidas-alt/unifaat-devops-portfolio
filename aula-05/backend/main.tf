# =============================================
# backend/main.tf — Remote State Backend
# S3 (state storage) + DynamoDB (state locking)
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================
#
# ⚠️  Execute ANTES da infraestrutura principal:
#     cd backend/ && terraform init && terraform apply
#
# Após o apply, copie o nome do bucket gerado para
# aula-05/providers.tf (bloco backend "s3").
#
# NOTA AWS Academy: o SCP da organização bloqueia
# s3:GetBucketObjectLockConfiguration. Por isso o
# bucket é criado via AWS CLI (null_resource) e os
# recursos de configuração (versioning, encryption,
# public access block) são gerenciados pelo Terraform.
# =============================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.bucket_prefix}-${var.ra}-${random_id.bucket_suffix.hex}"
}

resource "terraform_data" "s3_bucket" {
  input = local.bucket_name

  provisioner "local-exec" {
    command = <<-SH
      aws s3api create-bucket \
        --bucket "${local.bucket_name}" \
        --region "${var.aws_region}" \
        2>&1 || echo "bucket já existe, continuando..."
    SH
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-SH
      aws s3 rm "s3://${self.input}" --recursive 2>/dev/null || true
      aws s3api delete-bucket --bucket "${self.input}" 2>/dev/null || true
    SH
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = local.bucket_name

  versioning_configuration {
    status = "Enabled"
  }

  depends_on = [terraform_data.s3_bucket]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = local.bucket_name

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }

  depends_on = [terraform_data.s3_bucket]
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = local.bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [terraform_data.s3_bucket]
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = local.bucket_name

  depends_on = [aws_s3_bucket_public_access_block.terraform_state]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${local.bucket_name}",
          "arn:aws:s3:::${local.bucket_name}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name    = var.dynamodb_table_name
    Purpose = "terraform-state-lock"
  }
}