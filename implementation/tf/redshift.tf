# ═══════════════════ REDSHIFT SERVERLESS ═══════════════════

resource "aws_redshiftserverless_namespace" "main" {
  namespace_name      = "${var.project}-ns-${var.env}"
  db_name             = "feedback_analytics"
  admin_username      = "admin"
  admin_user_password = "Ch4ng3M3!Str0ng#2025"
  kms_key_id          = aws_kms_key.main.arn
  iam_roles           = [aws_iam_role.redshift.arn]
  tags                = { Name = "${var.project}-redshift-ns" }
}

resource "aws_redshiftserverless_workgroup" "main" {
  namespace_name      = aws_redshiftserverless_namespace.main.namespace_name
  workgroup_name      = "${var.project}-wg-${var.env}"
  base_capacity       = 8
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.redshift.id]
  publicly_accessible = false
  tags                = { Name = "${var.project}-redshift-wg" }
}

resource "aws_iam_role" "redshift" {
  name               = "${var.project}-redshift-${var.env}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "redshift.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy" "redshift" {
  name = "policy"
  role = aws_iam_role.redshift.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:GetObject", "s3:ListBucket"], Resource = [aws_s3_bucket.enriched.arn, "${aws_s3_bucket.enriched.arn}/*"] },
    { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = [aws_kms_key.main.arn] }
  ] })
}
