# =============================================
# networking.tf — VPC, Subnets, IGW, Route Tables
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ── Locals ────────────────────────────────────

locals {
  prefix = "technova"
}

# ── VPC ───────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

# ── Subnets Públicas (2 AZs) ──────────────────
# 10.0.1.0/24 → us-east-1a
# 10.0.3.0/24 → us-east-1b

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.prefix}-public-subnet-${count.index + 1}"
    Type = "public"
    AZ   = var.availability_zones[count.index]
  }
}

# ── Subnets Privadas (2 AZs) ──────────────────
# 10.0.2.0/24 → us-east-1a
# 10.0.4.0/24 → us-east-1b

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

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-igw"
  }
}

# ── Route Table Pública ───────────────────────
# Rota padrão 0.0.0.0/0 → IGW

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

# ── Associações: Route Table Pública → Subnets Públicas ──

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Nota: subnets privadas usam a Route Table padrão da VPC ──
# (sem rota para internet — comportamento padrão da AWS)
