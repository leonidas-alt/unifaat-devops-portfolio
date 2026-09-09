# =============================================
# security_groups.tf — Security Groups da TechNova
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ── Security Group da API ─────────────────────
# Porta 22  (SSH)  → 0.0.0.0/0
# Porta 3000 (API) → 0.0.0.0/0
# Egress: todo tráfego liberado

resource "aws_security_group" "api" {
  name        = "technova-api-sg"
  description = "Security Group para a API Node.js da TechNova"
  vpc_id      = aws_vpc.main.id

  # SSH — administração remota da instância
  ingress {
    description = "SSH para administracao da instancia"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # API Node.js
  ingress {
    description = "API Node.js porta ${var.api_port}"
    from_port   = var.api_port
    to_port     = var.api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: todo tráfego (necessário para instalar pacotes, clonar repo, etc.)
  egress {
    description = "Saida irrestrita"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "technova-api-sg"
  }
}

# ── Security Group do Banco de Dados (PostgreSQL) ──
# Porta 5432 → apenas da VPC interna (princípio do menor privilégio)
# Egress: todo tráfego liberado

resource "aws_security_group" "db" {
  name        = "technova-db-sg"
  description = "Security Group para o banco PostgreSQL (acesso interno apenas)"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL — apenas tráfego interno da VPC
  ingress {
    description = "PostgreSQL - acesso apenas da VPC interna"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress: todo tráfego
  egress {
    description = "Saida irrestrita"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "technova-db-sg"
  }
}
