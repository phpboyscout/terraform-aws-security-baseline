# ----------------------------------------------------------------------
# Root inputs — 14 variables (4 required, 10 with smart defaults).
# Each sub-module is gated by its own `enable_*` toggle so callers can
# compose the baseline à la carte.
# ----------------------------------------------------------------------

variable "account_id" {
  description = "AWS account ID this module operates against. Threaded through every sub-module that needs it for principal scoping."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  description = "Primary region. The audit log + Config history buckets live here; GuardDuty / Security Hub / Access Analyzer run here; the operator role's region restriction defaults to this region only."
  type        = string
}

variable "project_name" {
  description = "Short, kebab-case identifier used to derive default resource names (audit log bucket, Config history bucket). Override the individual `*_name` inputs to break this convention."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 chars, lowercase letters/digits/hyphens, starting with a letter."
  }
}

variable "alerts_email" {
  description = "Email address subscribed to the alerts SNS topic. Required even when `enable_alerts = false` to keep the signature stable; ignored in that case. AWS will send a confirmation email on first apply."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alerts_email))
    error_message = "alerts_email must look like an email address."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource the sub-modules create. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

# ---------- Per-sub-module enables ------------------------------------

variable "enable_account_hardening" {
  description = "Whether to provision the account-hardening sub-module (password policy, S3 public-access block, EBS default encryption, optional alias adoption)."
  type        = bool
  default     = true
}

variable "enable_audit_logging" {
  description = "Whether to provision the audit-logging sub-module (multi-region CloudTrail + KMS-encrypted log bucket)."
  type        = bool
  default     = true
}

variable "enable_aws_config" {
  description = "Whether to provision the aws-config sub-module (Config recorder + delivery channel + history bucket)."
  type        = bool
  default     = true
}

variable "enable_threat_detection" {
  description = "Whether to provision the threat-detection sub-module (GuardDuty + Security Hub + Access Analyzer)."
  type        = bool
  default     = true
}

variable "enable_alerts" {
  description = "Whether to provision the alerts sub-module (SNS topic + email subscription + EventBridge rules)."
  type        = bool
  default     = true
}

variable "enable_operator_role" {
  description = "Whether to provision the operator-role sub-module (InfraAdmin with MFA-required trust + region-restriction policy)."
  type        = bool
  default     = true
}

# ---------- Cross-cutting overrides -----------------------------------

variable "allowed_regions" {
  description = "Regions the operator role is permitted to operate in. Null defaults to `[var.region]` (single-region restriction). Pass a wider list for multi-region setups, or `[]` to disable the restriction entirely."
  type        = list(string)
  default     = null
}

variable "audit_retention_days" {
  description = "Days noncurrent log object versions are retained before expiring. Applied to both the audit log bucket and the Config history bucket. Default 730 (two years) per the master spec's OQ4 resolution; override for stricter compliance regimes."
  type        = number
  default     = 730

  validation {
    condition     = var.audit_retention_days >= 90
    error_message = "audit_retention_days must be at least 90 days."
  }
}

# ---------- account-hardening pass-throughs ---------------------------

variable "manage_account_alias" {
  description = "Whether the account-hardening sub-module takes over the IAM account alias. Default false (caller may already manage it elsewhere). When true, `account_alias` must be the existing value."
  type        = bool
  default     = false
}

variable "account_alias" {
  description = "IAM account alias to import and manage. Required when `manage_account_alias = true`."
  type        = string
  default     = null
}

# ---------- audit-logging / aws-config naming overrides ---------------

variable "log_bucket_name" {
  description = "Override for the audit log bucket name. Defaults to `<project_name>-audit-logs-<account_id>`. S3 names are globally unique."
  type        = string
  default     = null
}

variable "config_bucket_name" {
  description = "Override for the Config history bucket name. Defaults to `<project_name>-config-<account_id>`."
  type        = string
  default     = null
}

# ---------- threat-detection pass-through -----------------------------

variable "securityhub_standards" {
  description = "Security Hub standards to subscribe to. See `modules/threat-detection/variables.tf` for the supported set."
  type        = set(string)
  default     = ["fsbp", "cis-v3"]
}

# ---------- operator-role pass-through --------------------------------

variable "operator_role_name" {
  description = "Name of the operator role."
  type        = string
  default     = "InfraAdmin"
}
