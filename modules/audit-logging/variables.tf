variable "account_id" {
  description = "AWS account ID. Used in service-principal source-ARN conditions on the log bucket policy."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  description = "Region the log bucket lives in. Surfaced via outputs so consuming stacks can reference the bucket's home region."
  type        = string
}

variable "log_bucket_name" {
  description = "S3 bucket name for the CloudTrail log archive. Must be globally unique. Convention: `<project>-audit-logs-<account_id>`."
  type        = string

  validation {
    condition     = length(var.log_bucket_name) >= 3 && length(var.log_bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.log_bucket_name))
    error_message = "log_bucket_name must be a valid S3 bucket name (3-63 chars, lowercase letters/digits/hyphens/dots, starts and ends alphanumeric)."
  }
}

variable "trail_name" {
  description = "Name of the CloudTrail trail."
  type        = string
  default     = "audit-logs"
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

variable "log_kms_alias" {
  description = "Alias for the log-encryption CMK, without the `alias/` prefix."
  type        = string
  default     = "audit-logs"
}

variable "log_kms_deletion_window_in_days" {
  description = "Days the log-encryption CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30."
  type        = number
  default     = 30

  validation {
    condition     = var.log_kms_deletion_window_in_days >= 7 && var.log_kms_deletion_window_in_days <= 30
    error_message = "log_kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "log_kms_enable_key_rotation" {
  description = "Whether AWS automatically rotates the log-encryption CMK's key material annually."
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Whether the CloudTrail trail captures events from all AWS regions. Recommended; only disable for cost-sensitive single-region deployments."
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Whether to log events for global services (IAM, CloudFront, Route53, etc.). Recommended."
  type        = bool
  default     = true
}

variable "enable_log_file_validation" {
  description = "Whether CloudTrail produces signed digests so log integrity can be verified after the fact. Recommended."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Days noncurrent log object versions are retained before expiring. Defaults to 730 (two years), per the master spec's OQ4 resolution."
  type        = number
  default     = 730

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "log_retention_days must be at least 90 days; CloudTrail logs less than 90 days old aren't useful for forensic timeline reconstruction."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads to the log bucket are aborted. Closes CKV_AWS_300."
  type        = number
  default     = 7
}
