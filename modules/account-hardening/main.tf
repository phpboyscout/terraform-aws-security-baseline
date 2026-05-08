# ----------------------------------------------------------------------
# account-hardening — IAM password policy, S3 account-wide public-access
# block, EBS default encryption + customer-managed CMK, and (optionally)
# adoption of the IAM account alias.
#
# All four primitives are always created; only the alias is opt-in
# because callers may already manage it elsewhere (Control Tower,
# OrgFormation, manual setup as an aws-nuke prerequisite).
# ----------------------------------------------------------------------

locals {
  tags = merge({ Component = "account-hardening" }, var.tags)
}

# ---------- IAM password policy ---------------------------------------

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = var.password_policy.minimum_password_length
  require_lowercase_characters   = var.password_policy.require_lowercase_characters
  require_uppercase_characters   = var.password_policy.require_uppercase_characters
  require_numbers                = var.password_policy.require_numbers
  require_symbols                = var.password_policy.require_symbols
  allow_users_to_change_password = var.password_policy.allow_users_to_change_password
  hard_expiry                    = var.password_policy.hard_expiry
  max_password_age               = var.password_policy.max_password_age
  password_reuse_prevention      = var.password_policy.password_reuse_prevention
}

# ---------- IAM account alias (opt-in) --------------------------------
# When `manage_account_alias = true`, the import block adopts the
# existing alias on first apply (the alias must already exist in
# AWS). Subsequent applies are no-ops unless the value changes.

import {
  for_each = var.manage_account_alias ? toset([var.account_alias]) : toset([])
  to       = aws_iam_account_alias.this[0]
  id       = each.value
}

resource "aws_iam_account_alias" "this" {
  count = var.manage_account_alias ? 1 : 0

  account_alias = var.account_alias
}

# ---------- S3 account-wide public-access block -----------------------

resource "aws_s3_account_public_access_block" "this" {
  account_id              = var.account_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- EBS default encryption + CMK ------------------------------

resource "aws_kms_key" "ebs_default" {
  description             = "Customer-managed CMK encrypting all new EBS volumes in this account."
  enable_key_rotation     = var.ebs_kms_enable_key_rotation
  deletion_window_in_days = var.ebs_kms_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.ebs_default.json
  tags                    = local.tags
}

resource "aws_kms_alias" "ebs_default" {
  name          = "alias/${var.ebs_kms_alias}"
  target_key_id = aws_kms_key.ebs_default.key_id
}

resource "aws_ebs_default_kms_key" "this" {
  key_arn = aws_kms_key.ebs_default.arn
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# Minimal key policy: account root admin only. AWS-managed services
# (Auto Scaling, EC2 fleet, RDS) that need to use the CMK should
# attach grants externally — see the README.
data "aws_iam_policy_document" "ebs_default" {
  # checkov:skip=CKV_AWS_111:kms:* on the CMK for the account root is the AWS-documented pattern; narrowing it risks an unrecoverable lockout from the key. See https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html
  # checkov:skip=CKV_AWS_109:Same as CKV_AWS_111 — root account requires full control of the CMK.
  # checkov:skip=CKV_AWS_356:kms:* with Resource:* on the key itself is the only way to express "root has full control"; the policy IS the key, so the wildcard scope is the key's own ARN.
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
}
