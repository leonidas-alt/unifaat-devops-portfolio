# =============================================
# rds.tf - DB Subnet Group + RDS PostgreSQL 15
# TechNova - Emilly Santos de Oliveira (4023575)
# =============================================

# ── DB Subnet Group ───────────────────────────
# Agrupa as 2 subnets privadas (em AZs diferentes).
# O RDS exige pelo menos 2 AZs no Subnet Group,
# mesmo que multi_az = false.

resource "aws_db_subnet_group" "main" {
  name        = "${local.prefix}-db-subnet-group"
  description = "Subnet Group do RDS TechNova - subnets privadas em 2 AZs"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${local.prefix}-db-subnet-group"
  }
}

# ── RDS PostgreSQL 15 ─────────────────────────
#
# Configuração Free Tier / lab:
#   • db.t3.micro           - instância elegível ao Free Tier
#   • gp2 20 GB             - armazenamento mínimo
#   • multi_az = false      - sem standby (economiza custo)
#   • publicly_accessible   = false  - sem endpoint público
#   • storage_encrypted     = true   - encriptação em repouso
#   • skip_final_snapshot   = true   - sem snapshot ao destruir (lab)
#   • deletion_protection   = false  - permite terraform destroy

resource "aws_db_instance" "postgres" {
  identifier = "${local.prefix}-postgres"

  # ── Engine ─────────────────────────────────
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # ── Armazenamento ──────────────────────────
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100 # Auto Scaling de disco até 100 GB
  storage_type          = "gp2"
  storage_encrypted     = true

  # ── Banco e Credenciais ────────────────────
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  # ── Rede ───────────────────────────────────
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  # ── Backup e Manutenção ───────────────────
  backup_retention_period = 0     # sem backups automáticos em lab
  skip_final_snapshot     = true  # permite destroy sem snapshot
  deletion_protection     = false # permite terraform destroy

  # ── Performance Insights ──────────────────
  performance_insights_enabled = false # free tier não inclui

  # ── Parâmetros ────────────────────────────
  # parameter_group_name deixamos como default (postgres15)

  # ── Tags ──────────────────────────────────
  tags = {
    Name   = "${local.prefix}-postgres"
    Engine = "PostgreSQL"
  }

  # Aguarda o Subnet Group e SG existirem
  depends_on = [
    aws_db_subnet_group.main,
    aws_security_group.rds,
  ]
}
