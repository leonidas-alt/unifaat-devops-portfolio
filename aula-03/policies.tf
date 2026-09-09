# =============================================
# policies.tf — Custom IAM Policies + Attachments
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================

# ─────────────────────────────────────────────
# POLICY 1: S3 Read-only em buckets technova-*
# Anexada ao grupo: developers
# ─────────────────────────────────────────────

resource "aws_iam_policy" "s3_read" {
  name        = "${local.prefix}-s3-read"
  description = "Leitura restrita a buckets S3 com prefixo technova-*"
  path        = "/technova/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ListBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::technova-*"
      },
      {
        Sid    = "AllowS3GetObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging"
        ]
        Resource = "arn:aws:s3:::technova-*/*"
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.prefix}-s3-read"
  })
}

# ─────────────────────────────────────────────
# POLICY 2: EC2 + S3 Full para platform-eng
# Condition: apenas instâncias com tag Project=TechNova
# Anexada ao grupo: platform-eng
# ─────────────────────────────────────────────

resource "aws_iam_policy" "ec2_s3_full" {
  name        = "${local.prefix}-ec2-s3-full"
  description = "Gerenciamento EC2 (com tag) e leitura/escrita S3 technova-*"
  path        = "/technova/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2StartStopTagged"
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances"
        ]
        Resource = "arn:aws:ec2:us-east-1:*:instance/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "TechNova"
          }
        }
      },
      {
        Sid    = "AllowS3ReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::technova-*",
          "arn:aws:s3:::technova-*/*"
        ]
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.prefix}-ec2-s3-full"
  })
}

# ─────────────────────────────────────────────
# POLICY 3: Deny explícito para ações destrutivas
# Anexada ao grupo: developers (proteção extra)
# ─────────────────────────────────────────────

resource "aws_iam_policy" "deny_destructive" {
  name        = "${local.prefix}-deny-destructive"
  description = "Bloqueia explicitamente ações de exclusão em S3 e encerramento de EC2"
  path        = "/technova/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyS3Destructive"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:DeleteBucketPolicy",
          "s3:DeleteBucketWebsite",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyEC2Terminate"
        Effect = "Deny"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.prefix}-deny-destructive"
  })
}

# ─────────────────────────────────────────────
# POLICY ATTACHMENTS
# ─────────────────────────────────────────────

# Policy s3-read → grupo developers
resource "aws_iam_group_policy_attachment" "developers_s3_read" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.s3_read.arn
}

# Policy deny-destructive → grupo developers
resource "aws_iam_group_policy_attachment" "developers_deny_destructive" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.deny_destructive.arn
}

# Policy ec2-s3-full → grupo platform-eng
resource "aws_iam_group_policy_attachment" "platform_eng_ec2_s3_full" {
  group      = aws_iam_group.platform_eng.name
  policy_arn = aws_iam_policy.ec2_s3_full.arn
}
