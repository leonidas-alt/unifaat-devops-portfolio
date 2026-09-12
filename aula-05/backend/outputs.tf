# =============================================
# backend/outputs.tf — Outputs do Backend
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

output "bucket_name" {
  description = "Nome do bucket S3 — use no backend 'bucket' do providers.tf"
  value       = local.bucket_name
}

output "bucket_region" {
  description = "Região do bucket S3 — use no backend 'region'"
  value       = var.aws_region
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB — use no backend 'dynamodb_table'"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB"
  value       = aws_dynamodb_table.terraform_lock.arn
}

output "backend_config_snippet" {
  description = "Bloco backend pronto para colar no providers.tf da infra principal"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${local.bucket_name}"
      key            = "aula-05/terraform.tfstate"
      region         = "${var.aws_region}"
      encrypt        = true
      dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
    }
  EOT
}
