# =============================================
# security_groups.tf - Security Groups da TechNova
# TechNova - Emilly Santos de Oliveira (4023575)
# =============================================
#
# ★ BÔNUS: O SG do RDS referencia o SG do EC2 como origem
#   em vez de usar CIDR da VPC - princípio do menor privilégio.
#   Apenas instâncias com o SG "technova-ec2-sg" podem
#   se conectar ao PostgreSQL na porta 5432.
# =============================================

# ── Security Group do EC2 ─────────────────────
# Porta 22   (SSH)  → 0.0.0.0/0  (administração remota)
# Porta 3000 (API)  → 0.0.0.0/0  (acesso público à API)
# Egress: todo tráfego liberado (para instalar psql, etc.)

resource "aws_security_group" "ec2" {
  name        = "technova-ec2-sg"
  description = "SG do EC2 TechNova - SSH (22) e API (3000)"
  vpc_id      = aws_vpc.main.id

  # SSH - administração remota
  ingress {
    description = "SSH para administracao da instancia"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # API Node.js / porta configurável
  ingress {
    description = "API TechNova porta ${var.api_port}"
    from_port   = var.api_port
    to_port     = var.api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: necessário para yum/dnf, psql, conexão ao RDS
  egress {
    description = "Saida irrestrita"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "technova-ec2-sg"
    Role = "EC2 Application Server"
  }
}

# ── Security Group do RDS ─────────────────────
# ★ BÔNUS: origem é o SG do EC2, não o CIDR da VPC.
#   Isso garante que SOMENTE instâncias EC2 com o SG
#   "technova-ec2-sg" possam acessar o PostgreSQL.
#
# Porta 5432 (PostgreSQL) → security_groups = [aws_security_group.ec2.id]

resource "aws_security_group" "rds" {
  name        = "technova-rds-sg"
  description = "SG do RDS PostgreSQL - acesso apenas do SG do EC2"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL - apenas do EC2 da TechNova (★ bônus: SG reference)
  ingress {
    description     = "PostgreSQL apenas do EC2 TechNova"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Egress: RDS precisa de saída para atualizações e monitoramento AWS
  egress {
    description = "Saida irrestrita"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "technova-rds-sg"
    Role = "RDS PostgreSQL"
  }
}
