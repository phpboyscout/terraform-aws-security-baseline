variable "account_id" {
  description = "AWS account ID. Used in topic policy conditions and rule source-account scoping."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "alerts_email" {
  description = "Email address subscribed to the alerts topic. AWS will send a confirmation email on first apply — the subscription is `PendingConfirmation` until clicked."
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alerts_email))
    error_message = "alerts_email must look like an email address."
  }
}

variable "topic_name" {
  description = "Name of the SNS alerts topic."
  type        = string
  default     = "security-alerts"
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

variable "kms_alias" {
  description = "Alias for the SNS-encryption CMK, without the `alias/` prefix."
  type        = string
  default     = "sns-alerts"
}

variable "kms_deletion_window_in_days" {
  description = "Days the SNS CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "kms_enable_key_rotation" {
  description = "Whether AWS automatically rotates the SNS CMK's key material annually."
  type        = bool
  default     = true
}

variable "enable_guardduty_finding_rule" {
  description = "Whether to create an EventBridge rule forwarding GuardDuty findings of severity HIGH or CRITICAL (numeric ≥ 7) to the alerts topic."
  type        = bool
  default     = true
}

variable "enable_securityhub_finding_rule" {
  description = "Whether to create an EventBridge rule forwarding Security Hub findings of severity HIGH or CRITICAL to the alerts topic. Excludes GuardDuty-sourced findings (deduped — they fire via the GuardDuty rule)."
  type        = bool
  default     = true
}

variable "enable_root_login_rule" {
  description = "Whether to create an EventBridge rule alerting on root-account console sign-in events. NOTE: console sign-in CloudTrail events originate in us-east-1; this rule only fires on it from regions that receive the multi-region trail copy. For complete coverage, additionally deploy this module to us-east-1 with this flag on."
  type        = bool
  default     = true
}

variable "enable_root_api_rule" {
  description = "Whether to create an EventBridge rule alerting on any non-ConsoleLogin API call made by the root user. Same multi-region caveat as the console-sign-in rule."
  type        = bool
  default     = true
}
