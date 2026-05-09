# ----------------------------------------------------------------------
# aws-config — Config recorder + delivery channel + history bucket.
#
# Same posture as audit-logging: hand-rolled bucket with prevent_destroy
# + TLS-only + SSE-KMS-only policy; customer-managed CMK; bucket policy
# scoped to the Config service principal via aws:SourceAccount.
# ----------------------------------------------------------------------

locals {
  tags = merge({ Component = "aws-config" }, var.tags)
}

# ---------- IAM role Config assumes -----------------------------------

resource "aws_iam_role" "this" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.role_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "role_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

# AWS-managed policy with the precise permissions Config needs to
# discover and snapshot resource configurations.
resource "aws_iam_role_policy_attachment" "managed" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Config also needs s3:PutObject + s3:GetBucketAcl on the history
# bucket — granted via the bucket policy below, not via the role
# policy. Plus kms:GenerateDataKey* + Decrypt on the encryption CMK
# — granted via the CMK key policy below.

# ---------- KMS key for Config history encryption ---------------------

resource "aws_kms_key" "config" {
  description             = "CMK encrypting AWS Config history in s3://${var.config_bucket_name}"
  enable_key_rotation     = var.config_kms_enable_key_rotation
  deletion_window_in_days = var.config_kms_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.config_kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "config" {
  name          = "alias/${var.config_kms_alias}"
  target_key_id = aws_kms_key.config.key_id
}

data "aws_iam_policy_document" "config_kms" {
  # checkov:skip=CKV_AWS_111:kms:* on the CMK for the account root is the AWS-documented pattern; narrowing it risks an unrecoverable lockout from the key.
  # checkov:skip=CKV_AWS_109:Same as CKV_AWS_111 — root account requires full control of the CMK.
  # checkov:skip=CKV_AWS_356:kms:* with Resource:* on the key itself is the only way to express "root has full control"; the policy IS the key.
  statement {
    sid    = "AllowAccountRootAdmin"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowConfigEncrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }

  # The Config recorder role needs to encrypt / decrypt history
  # objects when it reads them back during snapshot delivery.
  statement {
    sid    = "AllowConfigRoleUseKey"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

# ---------- History bucket --------------------------------------------

#trivy:ignore:AWS-0089 CloudTrail (audit-logging sub-module) is the audit log of bucket access; bucket-level access logs would duplicate the record. Same rationale as checkov CKV_AWS_18 below.
resource "aws_s3_bucket" "config" {
  # checkov:skip=CKV_AWS_18:CloudTrail (audit-logging sub-module) is the audit log of bucket access; bucket-level access logs would duplicate the record.
  # checkov:skip=CKV_AWS_144:Cross-region replication is overkill for a private Config history bucket; lifecycle + versioning + KMS gives durability and recovery.
  # checkov:skip=CKV2_AWS_62:Event notifications add no value here — there is no consumer.
  bucket = var.config_bucket_name
  tags   = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.config.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }

  rule {
    id     = "transition-and-expire-history"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 180
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.history_retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id
  policy = data.aws_iam_policy_document.config_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.config]
}

data "aws_iam_policy_document" "config_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.config.arn,
      "${aws_s3_bucket.config.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowConfigGetBucketAcl"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.config.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }

  statement {
    sid    = "AllowConfigPutObject"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.config.arn}/AWSLogs/${var.account_id}/Config/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# ---------- Recorder + delivery channel + start logging ---------------

resource "aws_config_configuration_recorder" "this" {
  name     = var.recorder_name
  role_arn = aws_iam_role.this.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = var.include_global_resource_types
  }

  depends_on = [aws_iam_role_policy_attachment.managed]
}

resource "aws_config_delivery_channel" "this" {
  name           = var.delivery_channel_name
  s3_bucket_name = aws_s3_bucket.config.id
  s3_kms_key_arn = aws_kms_key.config.arn

  snapshot_delivery_properties {
    delivery_frequency = var.snapshot_delivery_frequency
  }

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_policy.config,
  ]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
