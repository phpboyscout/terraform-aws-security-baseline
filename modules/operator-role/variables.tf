variable "account_id" {
  description = "AWS account ID. Used as the trusted principal in the role's assume-role policy."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  description = "Primary region. Defaults `allowed_regions` to a single-element list containing this when allowed_regions is null."
  type        = string
}

variable "role_name" {
  description = "Name of the operator role."
  type        = string
  default     = "InfraAdmin"
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

# ---------- Trust policy ----------------------------------------------

variable "require_mfa" {
  description = "Whether the assume-role trust policy requires `aws:MultiFactorAuthPresent = true`. Strongly recommended for any role granting administrative access. Disable only for break-glass / emergency-only roles where MFA is impossible."
  type        = bool
  default     = true
}

variable "mfa_age" {
  description = "Maximum age, in seconds, of the MFA verification when assuming the role. Default 14400 (4 hours) balances security against operator friction."
  type        = number
  default     = 14400

  validation {
    condition     = var.mfa_age >= 900 && var.mfa_age <= 129600
    error_message = "mfa_age must be 900-129600 seconds (15 minutes to 36 hours)."
  }
}

variable "max_session_duration" {
  description = "Maximum session duration, in seconds, when assuming this role. AWS-allowed range 3600-43200."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be 3600-43200 seconds (1-12 hours)."
  }
}

# ---------- Permissions -----------------------------------------------

variable "attach_admin_policy" {
  description = "Whether to attach the AWS-managed `AdministratorAccess` policy. Default true — appropriate for the operator role for a single-tenant account. For tighter setups, set false and pass narrower policies via `additional_policy_arns`."
  type        = bool
  default     = true
}

variable "additional_policy_arns" {
  description = "ARNs of additional managed policies to attach to the role. Useful for layering AWS-managed policies (e.g. ReadOnlyAccess, IAMFullAccess) on top of, or instead of, AdministratorAccess."
  type        = set(string)
  default     = []
}

# ---------- Region restriction ----------------------------------------

variable "allowed_regions" {
  description = "Regions in which the operator role can operate. Null defaults to `[var.region]` (single-region restriction). Pass a wider list for multi-region setups, or an empty list `[]` to disable the restriction entirely."
  type        = list(string)
  default     = null
}

variable "globally_scoped_actions" {
  description = "IAM action prefixes for globally-scoped services that don't honour `aws:RequestedRegion` and must therefore be exempted from the region restriction. Default covers the standard global / billing services; extend to add provider-level globals or trim if you want to block specific global APIs."
  type        = list(string)
  default = [
    "iam:*",
    "sts:*",
    "cloudfront:*",
    "route53:*",
    "route53domains:*",
    "organizations:*",
    "support:*",
    "trustedadvisor:*",
    "waf:*",
    "wafv2:*",
    "shield:*",
    "globalaccelerator:*",
    "account:*",
    "aws-portal:*",
    "billing:*",
    "ce:*",
    "cur:*",
    "savingsplans:*",
    "tax:*",
    "payments:*",
    "health:*",
    "kms:DescribeKey",
    "kms:ListAliases",
  ]
}
