variable "account_id" {
  description = "AWS account ID. Used in service-principal source-ARN conditions on the Config history bucket policy."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "config_bucket_name" {
  description = "S3 bucket name for the AWS Config history archive. Must be globally unique. Convention: `<project>-config-<account_id>`."
  type        = string

  validation {
    condition     = length(var.config_bucket_name) >= 3 && length(var.config_bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.config_bucket_name))
    error_message = "config_bucket_name must be a valid S3 bucket name (3-63 chars, lowercase letters/digits/hyphens/dots, starts and ends alphanumeric)."
  }
}

variable "recorder_name" {
  description = "Name of the Config configuration recorder."
  type        = string
  default     = "default"
}

variable "delivery_channel_name" {
  description = "Name of the Config delivery channel."
  type        = string
  default     = "default"
}

variable "iam_role_name" {
  description = "Name of the IAM role Config assumes to record resources."
  type        = string
  default     = "aws-config-recorder"
}

variable "tags" {
  description = "Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict."
  type        = map(string)
  default     = {}
}

variable "config_kms_alias" {
  description = "Alias for the Config history-encryption CMK, without the `alias/` prefix."
  type        = string
  default     = "aws-config"
}

variable "config_kms_deletion_window_in_days" {
  description = "Days the Config CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30."
  type        = number
  default     = 30

  validation {
    condition     = var.config_kms_deletion_window_in_days >= 7 && var.config_kms_deletion_window_in_days <= 30
    error_message = "config_kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "config_kms_enable_key_rotation" {
  description = "Whether AWS automatically rotates the Config CMK's key material annually."
  type        = bool
  default     = true
}

variable "include_global_resource_types" {
  description = "Whether the recorder includes global resource types (IAM, CloudFront, Route53, etc.). Enable on the primary region only — running in multiple regions duplicates the global-resource cost without adding signal. Ignored when `excluded_resource_types` is set: AWS requires `false` under the exclusion strategy, and still records IAM in Regions that had Config before February 2022."
  type        = bool
  default     = true
}

variable "excluded_resource_types" {
  description = "Resource types the recorder leaves out, such as `AWS::EC2::Instance`. Empty records every supported type. Non-empty switches the recorder to `EXCLUSION_BY_RESOURCE_TYPES`, which still records new types as AWS adds them, and forces `include_global_resource_types` to `false`."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for t in var.excluded_resource_types : startswith(t, "AWS::")])
    error_message = "excluded_resource_types entries must be AWS resource types starting with `AWS::`, such as `AWS::EC2::Instance`."
  }
}

variable "snapshot_delivery_frequency" {
  description = "Frequency Config snapshots are delivered to the bucket. One of `One_Hour`, `Three_Hours`, `Six_Hours`, `Twelve_Hours`, `TwentyFour_Hours`."
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition     = contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.snapshot_delivery_frequency)
    error_message = "snapshot_delivery_frequency must be one of the AWS-allowed values."
  }
}

variable "history_retention_days" {
  description = "Days noncurrent Config history object versions are retained before expiring. Defaults to 730 (two years), matching audit-logging."
  type        = number
  default     = 730

  validation {
    condition     = var.history_retention_days >= 90
    error_message = "history_retention_days must be at least 90 days."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads to the history bucket are aborted. Closes CKV_AWS_300."
  type        = number
  default     = 7
}
