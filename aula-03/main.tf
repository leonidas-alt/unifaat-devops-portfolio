# =============================================
# main.tf — IAM Groups, Users e Memberships
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

locals {
  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = var.disciplina
    Aula       = "03"
  }
  prefix = "${var.ra}-technova"
}

# ─────────────────────────────────────────────
# IAM GROUPS
# ─────────────────────────────────────────────

resource "aws_iam_group" "developers" {
  name = "${local.prefix}-developers"
  path = "/technova/"
}

resource "aws_iam_group" "platform_eng" {
  name = "${local.prefix}-platform-eng"
  path = "/technova/"
}

# ─────────────────────────────────────────────
# IAM USERS
# ─────────────────────────────────────────────

resource "aws_iam_user" "juliana_dev" {
  name = "${var.ra}-juliana-dev"
  path = "/technova/"

  tags = merge(local.tags, {
    Name = "${var.ra}-juliana-dev"
    Role = "Developer"
  })
}

resource "aws_iam_user" "rafael_platform" {
  name = "${var.ra}-rafael-platform"
  path = "/technova/"

  tags = merge(local.tags, {
    Name = "${var.ra}-rafael-platform"
    Role = "Platform Engineer"
  })
}

resource "aws_iam_user" "lucas_intern" {
  name = "${var.ra}-lucas-intern"
  path = "/technova/"

  tags = merge(local.tags, {
    Name = "${var.ra}-lucas-intern"
    Role = "Intern"
  })
}

# ─────────────────────────────────────────────
# GROUP MEMBERSHIPS
# ─────────────────────────────────────────────

# Grupo developers: juliana, rafael, lucas
resource "aws_iam_group_membership" "developers_membership" {
  name  = "${local.prefix}-developers-membership"
  group = aws_iam_group.developers.name

  users = [
    aws_iam_user.juliana_dev.name,
    aws_iam_user.rafael_platform.name,
    aws_iam_user.lucas_intern.name,
  ]
}

# Grupo platform-eng: apenas rafael
resource "aws_iam_group_membership" "platform_eng_membership" {
  name  = "${local.prefix}-platform-eng-membership"
  group = aws_iam_group.platform_eng.name

  users = [
    aws_iam_user.rafael_platform.name,
  ]
}
