# =============================================
# ec2.tf - Key Pair, AMI data source e EC2
# TechNova - Emilly Santos de Oliveira (4023575)
# =============================================
#
# ★ BÔNUS: user_data instala o cliente PostgreSQL (psql)
#   e testa a conexão ao RDS automaticamente,
#   salvando o resultado em /var/log/rds-test.log
# =============================================

# ── Data Source: Amazon Linux 2023 AMI ───────

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ── TLS Key Pair (gerado pelo Terraform) ─────

resource "tls_private_key" "technova" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "technova" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.technova.public_key_openssh

  tags = {
    Name = "technova-key-aula05"
  }
}

# Salva a chave privada localmente (permissão 600 para SSH)
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.technova.private_key_pem
  filename        = "${path.module}/technova-key.pem"
  file_permission = "0600"
}

# ── User Data ★ BÔNUS ────────────────────────
# 1. Atualiza o sistema
# 2. Instala postgresql15 (cliente psql)
# 3. Testa conexão ao RDS e salva resultado em log
# 4. Cria tabela "orders" e insere dados de exemplo
# 5. Consulta a tabela (evidência para o PR)

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/user-data.log 2>&1

    echo "========================================"
    echo "TechNova EC2 Bootstrap - Aula 05"
    echo "RA: ${var.ra} | $(date)"
    echo "========================================"

    # ── 1. Atualizar sistema ──────────────────
    dnf update -y

    # ── 2. Instalar cliente PostgreSQL ────────
    # Amazon Linux 2023 usa dnf com repositório PostgreSQL
    dnf install -y postgresql15

    echo "psql instalado: $(psql --version)"

    # ── 3. Aguardar RDS ficar disponível ──────
    # O RDS pode demorar alguns minutos após o apply.
    # Tentamos por até 5 minutos (30 tentativas × 10s).
    echo "Aguardando RDS ficar disponível..."
    RDS_HOST="${aws_db_instance.postgres.address}"
    RDS_PORT="${var.db_port}"
    RDS_USER="${var.db_username}"
    RDS_DB="${var.db_name}"

    for i in $(seq 1 30); do
      if pg_isready -h "$RDS_HOST" -p "$RDS_PORT" -U "$RDS_USER" -d "$RDS_DB" 2>/dev/null; then
        echo "RDS disponível após $i tentativa(s)."
        break
      fi
      echo "Tentativa $i/30 - aguardando 10s..."
      sleep 10
    done

    # ── 4. Testar conexão e versão do PostgreSQL ──
    echo "--- Teste de Conexão ao RDS ---" | tee /var/log/rds-test.log
    PGPASSWORD="${var.db_password}" psql \
      -h "$RDS_HOST" \
      -p "$RDS_PORT" \
      -U "$RDS_USER" \
      -d "$RDS_DB" \
      -c "SELECT version();" \
      2>&1 | tee -a /var/log/rds-test.log

    # ── 5. Criar tabela orders e dados de exemplo ──
    echo "--- Criando tabela orders ---" | tee -a /var/log/rds-test.log
    PGPASSWORD="${var.db_password}" psql \
      -h "$RDS_HOST" \
      -p "$RDS_PORT" \
      -U "$RDS_USER" \
      -d "$RDS_DB" \
      -c "
        CREATE TABLE IF NOT EXISTS orders (
          id          SERIAL PRIMARY KEY,
          product     VARCHAR(100) NOT NULL,
          quantity    INTEGER NOT NULL,
          unit_price  NUMERIC(10,2) NOT NULL,
          created_at  TIMESTAMP DEFAULT NOW()
        );

        INSERT INTO orders (product, quantity, unit_price) VALUES
          ('Notebook TechNova Pro',  2, 3499.90),
          ('Mouse Ergonômico',      10,   89.90),
          ('Teclado Mecânico',       5,  299.90),
          ('Monitor 24\" Full HD',   3,  899.90),
          ('Headset USB',            8,  149.90)
        ON CONFLICT DO NOTHING;
      " \
      2>&1 | tee -a /var/log/rds-test.log

    # ── 6. Consultar dados (evidência para o PR) ──
    echo "--- SELECT * FROM orders ---" | tee -a /var/log/rds-test.log
    PGPASSWORD="${var.db_password}" psql \
      -h "$RDS_HOST" \
      -p "$RDS_PORT" \
      -U "$RDS_USER" \
      -d "$RDS_DB" \
      -c "SELECT id, product, quantity, unit_price, created_at FROM orders ORDER BY id;" \
      2>&1 | tee -a /var/log/rds-test.log

    echo "========================================"
    echo "Bootstrap concluído! Log em /var/log/rds-test.log"
    echo "========================================"
  EOF
}

# ── EC2 Instance ──────────────────────────────

resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # Subnet pública - EC2 fica exposta para SSH e API
  subnet_id = aws_subnet.public.id

  # Security Group do EC2 (SSH 22 + API 3000)
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Key Pair para acesso SSH
  key_name = aws_key_pair.technova.key_name

  # Instance Profile (★ bonus IAM - desabilitado no AWS Academy)
  # iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # Bootstrap: instala psql e testa conexão ao RDS
  user_data                   = local.user_data
  user_data_replace_on_change = true

  # Volume raiz: 20 GB gp3
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "technova-ec2-root-aula05"
    }
  }

  tags = {
    Name = "technova-app-ec2"
    Role = "Application Server"
    AZ   = var.availability_zones[0]
  }

  # Aguarda IGW e o RDS antes de iniciar
  # (sem IGW não há saída para instalar pacotes)
  depends_on = [
    aws_internet_gateway.main,
    aws_db_instance.postgres,
  ]
}
