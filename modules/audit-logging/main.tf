# ----------------------------------------------------------------------
# audit-logging — multi-region CloudTrail trail backed by an S3 log
# archive bucket and a customer-managed KMS CMK. Hand-rolled because
# the gnarly part (service-principal access in the bucket and KMS
# policies) is short enough to keep direct control over, and we want
# the same `prevent_destroy` + TLS-only / SSE-KMS-only policy the
# state bucket has.
# ----------------------------------------------------------------------

locals {
  tags = merge({ Component = "audit-logging" }, var.tags)
}

# ---------- KMS key for log encryption --------------------------------

resource "aws_kms_key" "logs" {
  description             = "CMK encrypting CloudTrail logs in s3://${var.log_bucket_name}"
  enable_key_rotation     = var.log_kms_enable_key_rotation
  deletion_window_in_days = var.log_kms_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.logs_kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.log_kms_alias}"
  target_key_id = aws_kms_key.logs.key_id
}

data "aws_iam_policy_document" "logs_kms" {
  # checkov:skip=CKV_AWS_111:kms:* on the CMK for the account root is the AWS-documented pattern; narrowing it risks an unrecoverable lockout from the key. See https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html
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

  # CloudTrail needs to GenerateDataKey* + DescribeKey to encrypt log
  # files with this CMK. Source-ARN condition pins to a trail in this
  # account.
  statement {
    sid    = "AllowCloudTrailEncrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${var.account_id}:trail/*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }

  # CloudTrail Decrypt is required to read its own logs back during
  # log-file-validation. Same source-ARN condition.
  statement {
    sid    = "AllowCloudTrailDecrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# ---------- Log bucket -------------------------------------------------

resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV_AWS_18:CloudTrail itself is the audit log of bucket access — additional access logs would duplicate the record and add another bucket to manage.
  # checkov:skip=CKV_AWS_144:Cross-region replication is overkill for a private audit bucket; lifecycle + versioning + KMS gives durability and recovery.
  # checkov:skip=CKV2_AWS_62:Event notifications add no value here — there is no consumer; alerting comes from EventBridge on CloudTrail event types directly, not on bucket events.
  bucket = var.log_bucket_name
  tags   = local.tags

  # Hard floor: the audit log bucket must not be destroyed by a `tofu
  # destroy`. Recovering log history is impossible after deletion.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }

  rule {
    id     = "transition-and-expire-logs"
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
      noncurrent_days = var.log_retention_days
    }
  }
}

# Bucket policy: deny non-TLS, allow CloudTrail PutObject + GetBucketAcl
# (the latter is a CloudTrail-internal precondition).
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket.json

  # The bucket policy depends on the public-access-block being applied
  # first, otherwise AWS will reject the policy with "Public access
  # block configuration is not yet effective".
  depends_on = [aws_s3_bucket_public_access_block.logs]
}

data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowCloudTrailGetBucketAcl"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.logs.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${var.region}:${var.account_id}:trail/${var.trail_name}"]
    }
  }

  statement {
    sid    = "AllowCloudTrailPutObject"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/AWSLogs/${var.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${var.region}:${var.account_id}:trail/${var.trail_name}"]
    }
  }
}

# ---------- The trail itself ------------------------------------------

resource "aws_cloudtrail" "this" {
  # checkov:skip=CKV_AWS_252:Findings fan into SNS via the alerts sub-module's EventBridge rules — wiring SNS directly to the trail would duplicate alerts.
  # checkov:skip=CKV2_AWS_10:CloudWatch Logs integration deliberately omitted — S3 + EventBridge is sufficient for our use case and CloudWatch Logs adds per-event ingestion cost without additional signal at this scale.
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.logs.id
  kms_key_id                    = aws_kms_key.logs.arn
  is_multi_region_trail         = var.is_multi_region_trail
  include_global_service_events = var.include_global_service_events
  enable_log_file_validation    = var.enable_log_file_validation
  enable_logging                = true

  tags = local.tags

  # CloudTrail's StartLogging silently fails if the bucket policy
  # isn't in place by the time the trail is created. Force ordering.
  depends_on = [aws_s3_bucket_policy.logs]
}
