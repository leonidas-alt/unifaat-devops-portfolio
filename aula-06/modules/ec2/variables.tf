# modules/ec2/variables.tf

variable "instance_name" {
  description = "Nome da instância EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "ID da AMI a ser utilizada"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet onde a instância será criada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de IDs dos Security Groups associados à instância"
  type        = list(string)
}

variable "key_name" {
  description = "Nome do key pair para acesso SSH"
  type        = string
}

variable "user_data" {
  description = "Script de user data (opcional)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}
