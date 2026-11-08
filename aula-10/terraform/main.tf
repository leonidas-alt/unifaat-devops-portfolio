# ──────────────────────────────────────────────────────────────────────────────
# main.tf — Recursos principais
# Aula 10: Terraform GitOps + CD Pipeline
# Aluno: Emilly Santos de Oliveira (RA: 4023575)
#
# Recursos criados:
#   - VPC + Subnet pública + Internet Gateway + Route Table
#   - Security Group (SSH + porta 3000)
#   - EC2 t2.micro com Docker instalado via user_data
#   - ECR Repository para as imagens Docker
# ──────────────────────────────────────────────────────────────────────────────

# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

# ── VPC ───────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw-${var.environment}"
  }
}

# ── Subnet pública ────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-public-${var.environment}"
  }
}

# ── Route Table ───────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rtb-public-${var.environment}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── Security Group ────────────────────────────────────────────────────────────

resource "aws_security_group" "api" {
  name        = "${var.project_name}-sg-api-${var.environment}"
  description = "Security Group da TechNova API — aula-10"
  vpc_id      = aws_vpc.main.id

  # SSH (restrito — em prod use apenas IPs específicos)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # API Node.js
  ingress {
    description = "TechNova API"
    from_port   = var.api_port
    to_port     = var.api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Saída irrestrita
  egress {
    description = "Saída irrestrita"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-api-${var.environment}"
  }
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = var.key_pair_name

  # Instala Docker e configura AWS CLI no boot
  user_data = <<-EOT
    #!/bin/bash
    set -e

    # Atualiza sistema
    dnf update -y

    # Instala Docker
    dnf install -y docker
    systemctl enable docker
    systemctl start docker

    # Permite ec2-user usar Docker sem sudo
    usermod -aG docker ec2-user

    # Instala AWS CLI v2 (já vem no AL2023, mas garante atualização)
    dnf install -y aws-cli

    echo "Docker e AWS CLI instalados com sucesso" >> /var/log/user-data.log
  EOT

  tags = {
    Name      = "${var.project_name}-api-${var.environment}"
    ManagedBy = "terraform"
  }
}

# ── ECR Repository ────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "api" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.ecr_repository_name
  }
}

# Política de ciclo de vida: mantém apenas as 10 imagens mais recentes
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as 10 imagens mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
