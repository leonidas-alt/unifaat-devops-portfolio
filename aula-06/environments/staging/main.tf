# environments/staging/main.tf
# Ambiente STAGING — mesmos módulos que dev, variáveis diferentes

# ============================================================
# Módulo 1: VPC
# CIDR 10.1.0.0/16 — diferente do dev (10.0.0.0/16)
# ============================================================
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  environment  = var.environment

  subnets = {
    "public-1"  = { cidr = "10.1.1.0/24", az = "us-east-1a", type = "public" }
    "public-2"  = { cidr = "10.1.2.0/24", az = "us-east-1b", type = "public" }
    "private-1" = { cidr = "10.1.3.0/24", az = "us-east-1a", type = "private" }
    "private-2" = { cidr = "10.1.4.0/24", az = "us-east-1b", type = "private" }
  }
}

# ============================================================
# Módulo 2: Security Group — API
# Composição: vpc_id vem do output do módulo VPC ↑
# ============================================================
module "api_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-api-sg"
  vpc_id       = module.vpc.vpc_id  # ← Output do módulo VPC
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from anywhere"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH from anywhere"
    }
  ]
}

# ============================================================
# Módulo 3: Security Group — RDS
# Composição: vpc_id vem do output do módulo VPC ↑
# ============================================================
module "rds_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-rds-sg"
  vpc_id       = module.vpc.vpc_id  # ← Output do módulo VPC
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "PostgreSQL from VPC"
    }
  ]
}

# ============================================================
# Módulo 4: EC2 — Servidor API
# Composição:
#   subnet_id          ← output de module.vpc (public_subnet_ids)
#   security_group_ids ← output de module.api_sg (sg_id)
# ============================================================
module "api_server" {
  source = "../../modules/ec2"

  instance_name      = "${var.project_name}-${var.environment}-api"
  instance_type      = "t2.micro"
  ami_id             = var.ami_id
  subnet_id          = module.vpc.public_subnet_ids[0]  # ← Output do módulo VPC
  security_group_ids = [module.api_sg.sg_id]            # ← Output do módulo SG
  key_name           = var.key_name
  environment        = var.environment
  project_name       = var.project_name
}

# ============================================================
# Módulo 5: RDS — Banco de dados PostgreSQL
# Composição:
#   subnet_ids         ← output de module.vpc (private_subnet_ids)
#   security_group_ids ← output de module.rds_sg (sg_id)
# ============================================================
module "database" {
  source = "../../modules/rds"

  db_name            = "technova_staging"
  db_username        = var.db_username
  db_password        = var.db_password
  subnet_ids         = module.vpc.private_subnet_ids    # ← Output do módulo VPC
  security_group_ids = [module.rds_sg.sg_id]            # ← Output do módulo SG
  instance_class     = "db.t3.micro"
  environment        = var.environment
  project_name       = var.project_name
}
