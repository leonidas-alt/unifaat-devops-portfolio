# =============================================
# roles.tf — Service Role EC2 + Instance Profile
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ─────────────────────────────────────────────
# TRUST POLICY: permite EC2 assumir a role
# ─────────────────────────────────────────────

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

# ─────────────────────────────────────────────
# IAM ROLE para instâncias EC2
# ─────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name               = "${local.prefix}-ec2-role"
  path               = "/technova/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "Role para instâncias EC2 da TechNova acessarem S3 app-data"

  tags = merge(local.tags, {
    Name = "${local.prefix}-ec2-role"
  })
}

# ─────────────────────────────────────────────
# PERMISSIONS POLICY: Read/Write em technova-app-data-*
# ─────────────────────────────────────────────

resource "aws_iam_policy" "ec2_s3_app_data" {
  name        = "${local.prefix}-ec2-s3-app-data"
  description = "Permite instâncias EC2 lerem e gravarem no bucket technova-app-data-*"
  path        = "/technova/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAppDataBucketList"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::technova-app-data-*"
      },
      {
        Sid    = "AllowAppDataObjectReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::technova-app-data-*/*"
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.prefix}-ec2-s3-app-data"
  })
}

# ─────────────────────────────────────────────
# ATTACHMENT: política → role
# ─────────────────────────────────────────────

resource "aws_iam_role_policy_attachment" "ec2_role_app_data" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_s3_app_data.arn
}

# ─────────────────────────────────────────────
# INSTANCE PROFILE: permite associar a role a EC2
# ─────────────────────────────────────────────

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.prefix}-ec2-profile"
  path = "/technova/"
  role = aws_iam_role.ec2_role.name

  tags = merge(local.tags, {
    Name = "${local.prefix}-ec2-profile"
  })
}
