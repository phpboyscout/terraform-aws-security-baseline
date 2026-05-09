variable "region" {
  description = "Region the detector / hub / analyzer run in. Used in Security Hub standards ARNs."
  type        = string
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

# ---------- GuardDuty -------------------------------------------------

variable "enable_guardduty" {
  description = "Whether to provision a GuardDuty detector in this region."
  type        = bool
  default     = true
}

variable "guardduty_finding_publishing_frequency" {
  description = "How often GuardDuty exports updated findings to EventBridge. One of `FIFTEEN_MINUTES`, `ONE_HOUR`, `SIX_HOURS`. Faster = more responsive alerting; cost is identical."
  type        = string
  default     = "FIFTEEN_MINUTES"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_publishing_frequency)
    error_message = "guardduty_finding_publishing_frequency must be one of FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  }
}

# ---------- Security Hub ----------------------------------------------

variable "enable_securityhub" {
  description = "Whether to enable Security Hub in this region."
  type        = bool
  default     = true
}

variable "securityhub_standards" {
  description = "Security Hub standards to subscribe to. Use the keys from the supported set: `fsbp` (AWS Foundational Security Best Practices), `cis-v3` (CIS AWS Foundations Benchmark v3.0), `cis-v1.4` (CIS v1.4 — deprecated, prefer v3), `pci-dss` (PCI DSS — workload-specific, opt-in only)."
  type        = set(string)
  default     = ["fsbp", "cis-v3"]

  validation {
    condition = length([
      for s in var.securityhub_standards : s
      if !contains(["fsbp", "cis-v3", "cis-v1.4", "pci-dss"], s)
    ]) == 0
    error_message = "securityhub_standards entries must be one of: fsbp, cis-v3, cis-v1.4, pci-dss."
  }
}

variable "securityhub_enable_default_standards" {
  description = "Whether to let AWS auto-subscribe Security Hub to its current set of default standards. Default false — we explicitly manage subscriptions via `securityhub_standards` so what's enabled is deterministic."
  type        = bool
  default     = false
}

variable "securityhub_control_finding_generator" {
  description = "How Security Hub generates findings for controls. `SECURITY_CONTROL` (recommended; consolidated across standards) or `STANDARD_CONTROL` (legacy; one finding per standard per control)."
  type        = string
  default     = "SECURITY_CONTROL"

  validation {
    condition     = contains(["SECURITY_CONTROL", "STANDARD_CONTROL"], var.securityhub_control_finding_generator)
    error_message = "securityhub_control_finding_generator must be SECURITY_CONTROL or STANDARD_CONTROL."
  }
}

# ---------- IAM Access Analyzer ---------------------------------------

variable "enable_access_analyzer" {
  description = "Whether to provision an IAM Access Analyzer."
  type        = bool
  default     = true
}

variable "access_analyzer_name" {
  description = "Name of the analyzer."
  type        = string
  default     = "default-account"
}

variable "access_analyzer_type" {
  description = "Scope of the analyzer. `ACCOUNT` analyses just this account; `ORGANIZATION` requires AWS Organizations and analyses all member accounts (out of scope for single-account v0.1 setups)."
  type        = string
  default     = "ACCOUNT"

  validation {
    condition     = contains(["ACCOUNT", "ORGANIZATION"], var.access_analyzer_type)
    error_message = "access_analyzer_type must be ACCOUNT or ORGANIZATION."
  }
}
