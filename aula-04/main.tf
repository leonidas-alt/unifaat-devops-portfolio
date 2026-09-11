# =============================================
# main.tf — Aula 04: VPC + EC2 Multi-AZ
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================
#
# Ponto de entrada da infraestrutura TechNova.
# Orquestra os recursos definidos nos demais arquivos:
#
#   networking.tf      → VPC, subnets, IGW, route tables
#   security_groups.tf → SGs da API e do banco de dados
#   iam.tf             → IAM Role + Instance Profile
#   ec2.tf             → AMI, key pair, instância
#   outputs.tf         → URLs, IPs, comandos
# =============================================

# ── Data Source: conta e região correntes ────
# Usado nos outputs e validações

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ── Validação de região ───────────────────────
# Garante que o apply está sendo feito na região certa.
# Remove ou ajuste se usar outra região.

resource "terraform_data" "region_check" {
  lifecycle {
    precondition {
      condition     = data.aws_region.current.name == var.aws_region
      error_message = "A região configurada (${var.aws_region}) não coincide com a região ativa do provider (${data.aws_region.current.name}). Verifique as credenciais ou a variável aws_region."
    }
  }
}

# ── Resumo da infraestrutura ─────────────────
# Exibe informações consolidadas após o apply.
# Não cria recurso real — apenas documenta no state.

resource "terraform_data" "infra_summary" {
  input = {
    aluno       = var.aluno
    ra          = var.ra
    project     = var.project_name
    environment = var.environment
    region      = var.aws_region
    azs         = var.availability_zones
    vpc_cidr    = var.vpc_cidr
  }

  lifecycle {
    # Recria apenas se os metadados de identificação mudarem
    replace_triggered_by = []
  }
}
