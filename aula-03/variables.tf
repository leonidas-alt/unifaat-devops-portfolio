# =============================================
# Variáveis — Aula 03: Terraform + IAM
# TechNova — Emilly Santos de Oliveira
# =============================================

variable "project_name" {
  description = "Nome do projeto TechNova"
  type        = string
  default     = "TechNova"
}

variable "environment" {
  description = "Ambiente (development, staging, production)"
  type        = string
  default     = "development"
}

variable "aluno" {
  description = "Nome completo do aluno"
  type        = string
  default     = "Emilly Santos de Oliveira"
}

variable "ra" {
  description = "Número de matrícula (RA) do aluno"
  type        = string
  default     = "4023575"
}

variable "disciplina" {
  description = "Nome da disciplina"
  type        = string
  default     = "DevOps - UniFAAT 2026-2"
}
