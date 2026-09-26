# modules/vpc/variables.tf

variable "vpc_cidr" {
  description = "CIDR block principal da VPC"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets a serem criadas. Cada chave é o nome da subnet; o valor define cidr, az e type (public ou private)."
  type = map(object({
    cidr = string
    az   = string
    type = string
  }))
}
