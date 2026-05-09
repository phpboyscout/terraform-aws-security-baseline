# ----------------------------------------------------------------------
# operator-role — InfraAdmin role with an MFA-required trust policy and
# (optionally) an inline policy denying actions outside an allow-listed
# set of regions, with carve-outs for globally-scoped services.
#
# Hand-rolled rather than wrapping `terraform-aws-modules/iam//modules/
# iam-assumable-role` because the trust + MFA + region-restriction
# combination is small enough that the upstream wrapper adds no value.
# ----------------------------------------------------------------------

locals {
  tags = merge({ Component = "operator-role" }, var.tags)

  # Variable defaults can't reference other variables, so resolve here.
  effective_allowed_regions = var.allowed_regions != null ? var.allowed_regions : [var.region]

  region_restriction_enabled = length(local.effective_allowed_regions) > 0
}

# ---------- Trust policy ----------------------------------------------

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AccountRootAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }

    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }

    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "NumericLessThan"
        variable = "aws:MultiFactorAuthAge"
        values   = [tostring(var.mfa_age)]
      }
    }
  }
}

# ---------- Role + permission attachments -----------------------------

resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
  tags                 = local.tags
}

resource "aws_iam_role_policy_attachment" "admin" {
  # checkov:skip=CKV_AWS_274:AdministratorAccess is the deliberate purpose of this role — humans assume it with MFA to do anything administrative. Toggle off via attach_admin_policy = false to attach narrower policies.
  count = var.attach_admin_policy ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = var.additional_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# ---------- Region-restriction inline policy --------------------------
# Denies any action that is NOT one of `globally_scoped_actions` when
# the request's `aws:RequestedRegion` is outside `allowed_regions`.
# Using NotAction is the canonical pattern: callers can call IAM,
# CloudFront, Route53, etc. (which don't honour RequestedRegion)
# regardless of region, but anything regional is pinned to the allow
# list.

resource "aws_iam_role_policy" "region_restriction" {
  count = local.region_restriction_enabled ? 1 : 0

  name   = "region-restriction"
  role   = aws_iam_role.this.name
  policy = data.aws_iam_policy_document.region_restriction.json
}

data "aws_iam_policy_document" "region_restriction" {
  # checkov:skip=CKV_AWS_111:This is a Deny policy — it constrains, not grants. The "broad action scope" warning doesn't apply; broad actions are exactly the point of the deny.
  # checkov:skip=CKV_AWS_109:Same — Deny with broad NotAction is a region-fence, not a permission grant.
  # checkov:skip=CKV_AWS_356:Resources:* on Deny is correct here; the deny applies regardless of the resource being targeted.
  statement {
    sid         = "DenyOutsideAllowedRegions"
    effect      = "Deny"
    not_actions = var.globally_scoped_actions
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = local.effective_allowed_regions
    }
  }
}
