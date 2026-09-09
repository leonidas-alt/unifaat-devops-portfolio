# =============================================
# outputs.tf — Outputs do TF Aula 03: IAM
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ── Grupos ──────────────────────────────────

output "group_developers_arn" {
  description = "ARN do grupo IAM developers"
  value       = aws_iam_group.developers.arn
}

output "group_platform_eng_arn" {
  description = "ARN do grupo IAM platform-eng"
  value       = aws_iam_group.platform_eng.arn
}

# ── Usuários ─────────────────────────────────

output "user_juliana_dev_arn" {
  description = "ARN do usuário juliana-dev"
  value       = aws_iam_user.juliana_dev.arn
}

output "user_rafael_platform_arn" {
  description = "ARN do usuário rafael-platform"
  value       = aws_iam_user.rafael_platform.arn
}

output "user_lucas_intern_arn" {
  description = "ARN do usuário lucas-intern"
  value       = aws_iam_user.lucas_intern.arn
}

# ── Policies ─────────────────────────────────

output "policy_s3_read_arn" {
  description = "ARN da policy s3-read (developers)"
  value       = aws_iam_policy.s3_read.arn
}

output "policy_ec2_s3_full_arn" {
  description = "ARN da policy ec2-s3-full (platform-eng)"
  value       = aws_iam_policy.ec2_s3_full.arn
}

output "policy_deny_destructive_arn" {
  description = "ARN da policy deny-destructive (developers)"
  value       = aws_iam_policy.deny_destructive.arn
}

output "policy_ec2_s3_app_data_arn" {
  description = "ARN da policy ec2-s3-app-data (ec2-role)"
  value       = aws_iam_policy.ec2_s3_app_data.arn
}

# ── Role e Instance Profile ───────────────────

output "role_ec2_arn" {
  description = "ARN do Service Role para EC2"
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_arn" {
  description = "ARN do Instance Profile para EC2"
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "instance_profile_name" {
  description = "Nome do Instance Profile (usado ao lançar EC2)"
  value       = aws_iam_instance_profile.ec2_profile.name
}
