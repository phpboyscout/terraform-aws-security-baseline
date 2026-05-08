# ----------------------------------------------------------------------
# alerts — SNS topic + email subscription + EventBridge rules wiring
# high-severity findings (GuardDuty, Security Hub) and root-account
# activity (sign-in, API calls) to a single email address.
# ----------------------------------------------------------------------

locals {
  tags = merge({ Component = "alerts" }, var.tags)
}

# ---------- KMS key for SNS message encryption -------------------------

resource "aws_kms_key" "sns" {
  description             = "CMK encrypting messages on the security alerts SNS topic."
  enable_key_rotation     = var.kms_enable_key_rotation
  deletion_window_in_days = var.kms_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.sns_kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.sns.key_id
}

data "aws_iam_policy_document" "sns_kms" {
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

  # EventBridge needs to encrypt messages it puts onto the topic.
  statement {
    sid    = "AllowEventBridgePublishViaTopic"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# ---------- SNS topic + email subscription ----------------------------

resource "aws_sns_topic" "this" {
  name              = var.topic_name
  kms_master_key_id = aws_kms_key.sns.arn
  tags              = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.alerts_email

  # AWS sends a confirmation email; the subscription stays
  # PendingConfirmation until clicked. tofu plan won't detect the
  # eventual confirmation; that's expected.
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic.json
}

data "aws_iam_policy_document" "topic" {
  # Account principals retain full control of the topic (default
  # behaviour without an explicit policy; we replicate it so adding
  # other Allow statements doesn't strip it).
  statement {
    sid    = "AllowAccountFullControl"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["sns:*"]
    resources = [aws_sns_topic.this.arn]
  }

  # EventBridge publishes events from the rules below.
  statement {
    sid    = "AllowEventBridgePublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# ---------- EventBridge rules -----------------------------------------

# GuardDuty findings of severity HIGH (>= 7.0) or CRITICAL (>= 9.0).
# AWS only emits one HIGH/CRITICAL band — they're both numeric ≥ 7 in
# the GuardDuty schema.
resource "aws_cloudwatch_event_rule" "guardduty" {
  count = var.enable_guardduty_finding_rule ? 1 : 0

  name        = "${var.topic_name}-guardduty-high"
  description = "GuardDuty findings of severity HIGH or CRITICAL."
  tags        = local.tags

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  count = var.enable_guardduty_finding_rule ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty[0].name
  target_id = "sns"
  arn       = aws_sns_topic.this.arn
}

# Security Hub findings of severity HIGH or CRITICAL, EXCLUDING those
# imported from GuardDuty (deduped — they're already alerted via the
# guardduty rule above).
resource "aws_cloudwatch_event_rule" "securityhub" {
  count = var.enable_securityhub_finding_rule ? 1 : 0

  name        = "${var.topic_name}-securityhub-high"
  description = "Security Hub findings of severity HIGH or CRITICAL (excluding GuardDuty-sourced)."
  tags        = local.tags

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        ProductFields = {
          "aws/securityhub/ProductName" = [{ "anything-but" = "GuardDuty" }]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub_to_sns" {
  count = var.enable_securityhub_finding_rule ? 1 : 0

  rule      = aws_cloudwatch_event_rule.securityhub[0].name
  target_id = "sns"
  arn       = aws_sns_topic.this.arn
}

# Root-account console sign-in (CloudTrail event delivered to
# EventBridge via the multi-region trail).
resource "aws_cloudwatch_event_rule" "root_login" {
  count = var.enable_root_login_rule ? 1 : 0

  name        = "${var.topic_name}-root-login"
  description = "Root-account console sign-in."
  tags        = local.tags

  event_pattern = jsonencode({
    source        = ["aws.signin"]
    "detail-type" = ["AWS Console Sign In via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "root_login_to_sns" {
  count = var.enable_root_login_rule ? 1 : 0

  rule      = aws_cloudwatch_event_rule.root_login[0].name
  target_id = "sns"
  arn       = aws_sns_topic.this.arn
}

# Root-account API calls (anything that isn't a console sign-in).
# Catches programmatic root-credential use — should be near-zero in a
# well-run account.
resource "aws_cloudwatch_event_rule" "root_api" {
  count = var.enable_root_api_rule ? 1 : 0

  name        = "${var.topic_name}-root-api"
  description = "Root-account API call (excluding console sign-in)."
  tags        = local.tags

  event_pattern = jsonencode({
    source = ["aws.cloudtrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
      eventName = [{ "anything-but" = "ConsoleLogin" }]
    }
  })
}

resource "aws_cloudwatch_event_target" "root_api_to_sns" {
  count = var.enable_root_api_rule ? 1 : 0

  rule      = aws_cloudwatch_event_rule.root_api[0].name
  target_id = "sns"
  arn       = aws_sns_topic.this.arn
}
