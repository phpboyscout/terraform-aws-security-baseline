variable "account_id" {
  description = "AWS account ID. Used as the root principal in the EBS default-encryption KMS key policy."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

variable "manage_account_alias" {
  description = "Whether this module manages the IAM account alias. The default — false — leaves the alias as-is (set externally; e.g. as an aws-nuke prerequisite). Set true to take it over via an `import` block; in that case `account_alias` must be the existing alias value."
  type        = bool
  default     = false
}

variable "account_alias" {
  description = "The IAM account alias value to import and manage. Required when `manage_account_alias = true`; ignored otherwise. The alias must already exist in AWS — set it manually with `aws iam create-account-alias` before applying."
  type        = string
  default     = null
}

variable "password_policy" {
  description = "IAM account password policy. Defaults are sensible for any production workload; override per-field as needed."
  type = object({
    minimum_password_length        = optional(number, 14)
    require_lowercase_characters   = optional(bool, true)
    require_uppercase_characters   = optional(bool, true)
    require_numbers                = optional(bool, true)
    require_symbols                = optional(bool, true)
    allow_users_to_change_password = optional(bool, true)
    hard_expiry                    = optional(bool, false)
    max_password_age               = optional(number, 90)
    password_reuse_prevention      = optional(number, 24)
  })
  default = {}
}

variable "ebs_kms_alias" {
  description = "Alias for the EBS default-encryption CMK, without the `alias/` prefix."
  type        = string
  default     = "ebs-default"
}

variable "ebs_kms_deletion_window_in_days" {
  description = "Days the EBS default-encryption CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30."
  type        = number
  default     = 30

  validation {
    condition     = var.ebs_kms_deletion_window_in_days >= 7 && var.ebs_kms_deletion_window_in_days <= 30
    error_message = "ebs_kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "ebs_kms_enable_key_rotation" {
  description = "Whether AWS automatically rotates the EBS default-encryption CMK's key material annually."
  type        = bool
  default     = true
}
