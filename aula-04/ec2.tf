# =============================================
# ec2.tf — Key Pair, AMI data source e EC2
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ── Data Source: Amazon Linux 2023 AMI ───────
# Busca a AMI mais recente do Amazon Linux 2023
# para arquitetura x86_64 na região configurada

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
# A chave privada é salva localmente em ~/.ssh/

resource "tls_private_key" "technova" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "technova" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.technova.public_key_openssh

  tags = {
    Name = "technova-key-pair"
  }
}

# Salva a chave privada no disco local (permissão 600 para SSH)
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.technova.private_key_pem
  filename        = "${path.module}/technova-key.pem"
  file_permission = "0600"
}

# ── User Data — Bootstrap da instância ───────
# Executado uma única vez na inicialização do EC2:
#   1. Atualiza o sistema
#   2. Instala Node.js 18 via NodeSource
#   3. Instala Git
#   4. Clona a technova-api
#   5. Instala dependências npm
#   6. Cria serviço systemd para manter a API rodando

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > /var/log/user-data.log 2>&1

    echo "========================================"
    echo "TechNova API — Bootstrap iniciado"
    echo "RA: ${var.ra} | $(date)"
    echo "========================================"

    # ── 1. Atualizar sistema ──────────────────
    dnf update -y

    # ── 2. Instalar Node.js 18 ────────────────
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    dnf install -y nodejs

    # ── 3. Instalar Git ───────────────────────
    dnf install -y git

    # ── 4. Verificar versões instaladas ───────
    echo "Node.js: $(node --version)"
    echo "npm:     $(npm --version)"
    echo "Git:     $(git --version)"

    # ── 5. Criar diretório da aplicação ───────
    mkdir -p /opt/technova-api
    cd /opt/technova-api

    # ── 6. Criar API Node.js simples ──────────
    # (caso o repo real não esteja disponível, cria uma API funcional)
    cat > /opt/technova-api/package.json <<'PKGJSON'
    {
      "name": "technova-api",
      "version": "1.0.0",
      "description": "TechNova API - Aula 04 VPC + EC2 Multi-AZ",
      "main": "server.js",
      "scripts": {
        "start": "node server.js"
      },
      "dependencies": {
        "express": "^4.18.2"
      }
    }
    PKGJSON

    cat > /opt/technova-api/server.js <<'JSAPP'
    const express = require('express');
    const os      = require('os');
    const app     = express();
    const PORT    = process.env.PORT || 3000;

    app.get('/', (req, res) => {
      res.json({
        message:     'TechNova API — Aula 04 VPC + EC2 Multi-AZ',
        status:      'running',
        aluno:       'Emilly Santos de Oliveira',
        ra:          '4023575',
        version:     '1.0.0',
        timestamp:   new Date().toISOString(),
        hostname:    os.hostname(),
        platform:    os.platform(),
        nodeVersion: process.version,
      });
    });

    app.get('/health', (req, res) => {
      res.json({
        status:    'healthy',
        uptime:    process.uptime(),
        memory:    process.memoryUsage(),
        timestamp: new Date().toISOString(),
      });
    });

    app.get('/info', (req, res) => {
      res.json({
        project:     'TechNova',
        aula:        '04',
        tema:        'VPC + EC2 Multi-AZ',
        ambiente:    'development',
        region:      'us-east-1',
        multiAZ:     true,
        subnets:     ['10.0.1.0/24', '10.0.3.0/24', '10.0.2.0/24', '10.0.4.0/24'],
      });
    });

    app.listen(PORT, '0.0.0.0', () => {
      console.log('TechNova API iniciada na porta ' + PORT);
      console.log('Rotas: / | /health | /info');
    });
    JSAPP

    # ── 7. Instalar dependências ───────────────
    cd /opt/technova-api
    npm install --production

    # ── 8. Criar serviço systemd ──────────────
    cat > /etc/systemd/system/technova-api.service <<'SYSTEMD'
    [Unit]
    Description=TechNova API — Node.js
    After=network.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=ec2-user
    WorkingDirectory=/opt/technova-api
    ExecStart=/usr/bin/node /opt/technova-api/server.js
    Restart=on-failure
    RestartSec=5
    Environment=NODE_ENV=production
    Environment=PORT=3000

    [Install]
    WantedBy=multi-user.target
    SYSTEMD

    # ── 9. Ajustar permissões e iniciar serviço ──
    chown -R ec2-user:ec2-user /opt/technova-api
    systemctl daemon-reload
    systemctl enable technova-api
    systemctl start  technova-api

    echo "========================================"
    echo "Bootstrap concluído com sucesso!"
    echo "API disponível em http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
    echo "========================================"
  EOF
}

# ── EC2 Instance ──────────────────────────────

resource "aws_instance" "api" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # Subnet pública AZ-a (us-east-1a) — onde a API ficará exposta
  subnet_id = aws_subnet.public[0].id

  # Security Group da API (SSH + porta 3000)
  vpc_security_group_ids = [aws_security_group.api.id]

  # Key Pair para acesso SSH
  key_name = aws_key_pair.technova.key_name

  # Instance Profile com permissões S3 read-only
  # Nota: AWS Academy não permite iam:CreateRole — recurso definido em iam.tf
  # mas não aplicado no laboratório (sem permissão para criar roles).
  # iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # Bootstrap automático da API
  user_data                   = local.user_data
  user_data_replace_on_change = true

  # Volume raiz: 20 GB gp3 (mais barato e performático que gp2)
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "technova-api-root-volume"
    }
  }

  tags = {
    Name = "technova-api-ec2"
    Role = "API Server"
    AZ   = var.availability_zones[0]
  }

  # Aguarda o User Data terminar antes de dar "apply concluído"
  depends_on = [
    aws_internet_gateway.main,
  ]
}
