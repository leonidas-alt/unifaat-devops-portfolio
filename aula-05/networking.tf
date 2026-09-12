# =============================================
# networking.tf - VPC, Subnets, IGW, Route Tables
# TechNova - Emilly Santos de Oliveira (4023575)
# =============================================
#
# Topologia:
#   VPC 10.0.0.0/16
#   ├── Subnet pública  10.0.1.0/24  (us-east-1a) → EC2 + Internet Gateway
#   ├── Subnet privada  10.0.2.0/24  (us-east-1a) → RDS (nó principal)
#   └── Subnet privada  10.0.3.0/24  (us-east-1b) → RDS (DB Subnet Group exige 2 AZs)
# =============================================

# ── Locals ────────────────────────────────────

locals {
  prefix = lower(var.project_name)
}

# ── VPC ───────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # necessário para o endpoint do RDS resolver

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

# ── Subnet Pública ────────────────────────────
# EC2 fica aqui - recebe IP público automaticamente

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-public-subnet"
    Type = "public"
    AZ   = var.availability_zones[0]
  }
}

# ── Subnets Privadas (2 AZs) ──────────────────
# O DB Subnet Group do RDS exige subnets em pelo menos 2 AZs.
# Nenhuma tem rota para a internet - RDS não é acessível publicamente.

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.prefix}-private-subnet-${count.index + 1}"
    Type = "private"
    AZ   = var.availability_zones[count.index]
  }
}

# ── Internet Gateway ──────────────────────────
# Permite que a subnet pública tenha rota para a internet

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-igw"
  }
}

# ── Route Table Pública ───────────────────────
# Rota padrão: 0.0.0.0/0 → Internet Gateway

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.prefix}-public-rt"
    Type = "public"
  }
}

# ── Associação: Route Table → Subnet Pública ──

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── Subnets privadas usam a Route Table padrão da VPC ──
# (sem rota para a internet - comportamento padrão da AWS)
