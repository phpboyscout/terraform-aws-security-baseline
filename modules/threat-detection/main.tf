# ----------------------------------------------------------------------
# threat-detection — GuardDuty detector + Security Hub with explicit
# standards subscriptions + IAM Access Analyzer. Each gated by an
# enable_* toggle so callers can opt out of individual services
# without the whole sub-module dropping.
# ----------------------------------------------------------------------

locals {
  tags = merge({ Component = "threat-detection" }, var.tags)

  # Map user-friendly standard keys to their region-specific ARNs.
  # Update when AWS publishes a new standard or revs a major version
  # (e.g. CIS v4 lands).
  securityhub_standards_arns = {
    "fsbp"     = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
    "cis-v3"   = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/3.0.0"
    "cis-v1.4" = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
    "pci-dss"  = "arn:aws:securityhub:${var.region}::standards/pci-dss/v/3.2.1"
  }
}

# ---------- GuardDuty -------------------------------------------------

resource "aws_guardduty_detector" "this" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency
  tags                         = local.tags
}

# Optional GuardDuty features (Malware Protection, EKS Runtime
# Monitoring, RDS Protection, Lambda Network Activity Monitoring,
# S3 Logs) are deliberately NOT enabled in v0.1 — each carries
# additional cost and is workload-dependent. Callers that need them
# add `aws_guardduty_detector_feature` resources alongside this
# module reference.

# ---------- Security Hub ----------------------------------------------

resource "aws_securityhub_account" "this" {
  count = var.enable_securityhub ? 1 : 0

  enable_default_standards  = var.securityhub_enable_default_standards
  control_finding_generator = var.securityhub_control_finding_generator
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each = var.enable_securityhub ? var.securityhub_standards : toset([])

  standards_arn = local.securityhub_standards_arns[each.key]

  depends_on = [aws_securityhub_account.this]
}

# ---------- IAM Access Analyzer ---------------------------------------

resource "aws_accessanalyzer_analyzer" "this" {
  count = var.enable_access_analyzer ? 1 : 0

  analyzer_name = var.access_analyzer_name
  type          = var.access_analyzer_type
  tags          = local.tags
}
