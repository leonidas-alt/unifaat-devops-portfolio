# =============================================
# terraform.tfvars — Aula 04: VPC + EC2 Multi-AZ
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

project_name = "TechNova"
environment  = "development"
aluno        = "Emilly Santos de Oliveira"
ra           = "4023575"

aws_region         = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.2.0/24", "10.0.4.0/24"]

instance_type = "t2.micro"
key_pair_name = "technova-key"
api_port      = 3000
