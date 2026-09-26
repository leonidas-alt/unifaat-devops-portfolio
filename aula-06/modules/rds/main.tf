# modules/rds/main.tf

# ========================================
# DB Subnet Group
# Agrupa as subnets privadas para o RDS
# ========================================
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "DB Subnet Group para ${var.project_name} ${var.environment}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ========================================
# Instância RDS PostgreSQL
# ========================================
resource "aws_db_instance" "this" {
  identifier        = "${var.project_name}-${var.environment}-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.instance_class
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids

  # Configurações para ambiente de desenvolvimento/testes
  skip_final_snapshot = true
  publicly_accessible = false
  multi_az            = false
  deletion_protection = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-db"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
