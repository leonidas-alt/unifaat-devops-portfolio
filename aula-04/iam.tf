# =============================================
# iam.tf — IAM Role + Instance Profile para EC2
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ── Trust Policy para EC2 ─────────────────────
# Permite que instâncias EC2 assumam esta role

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ── IAM Role ──────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name               = "technova-ec2-role"
  description        = "Role para instancias EC2 da TechNova — acesso S3 read-only"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "technova-ec2-role"
  }
}

# ── Política: S3 Read Only ────────────────────
# Permite que a API leia objetos do S3 (ex: configs, assets)

resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ── Instance Profile ──────────────────────────
# Wrapper necessário para anexar a Role a uma instância EC2

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "technova-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "technova-ec2-profile"
  }
}
