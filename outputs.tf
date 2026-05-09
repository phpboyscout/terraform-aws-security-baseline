# ----------------------------------------------------------------------
# Root outputs — surface what consuming stacks need: ARNs to grant
# permissions on, KMS keys to use as workload-side encryption defaults,
# the alerts topic so downstream alarms fan into it, and the operator
# role for human assume-role flows.
# ----------------------------------------------------------------------

# ---------- account-hardening -----------------------------------------

output "ebs_default_kms_key_arn" {
  description = "ARN of the customer-managed CMK used as the EBS default-encryption key. Null when account-hardening is disabled."
  value       = var.enable_account_hardening ? module.account_hardening[0].ebs_default_kms_key_arn : null
}

output "account_alias" {
  description = "IAM account alias managed by the account-hardening sub-module. Null when account-hardening is disabled or `manage_account_alias = false`."
  value       = var.enable_account_hardening ? module.account_hardening[0].account_alias : null
}

# ---------- audit-logging ---------------------------------------------

output "audit_log_bucket_id" {
  description = "Name of the S3 bucket holding CloudTrail logs."
  value       = var.enable_audit_logging ? module.audit_logging[0].log_bucket_id : null
}

output "audit_log_bucket_arn" {
  description = "ARN of the audit log bucket."
  value       = var.enable_audit_logging ? module.audit_logging[0].log_bucket_arn : null
}

output "audit_log_kms_key_arn" {
  description = "ARN of the customer-managed CMK encrypting CloudTrail logs at rest."
  value       = var.enable_audit_logging ? module.audit_logging[0].log_kms_key_arn : null
}

output "audit_trail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = var.enable_audit_logging ? module.audit_logging[0].trail_arn : null
}

# ---------- aws-config ------------------------------------------------

output "aws_config_bucket_id" {
  description = "Name of the S3 bucket holding AWS Config history."
  value       = var.enable_aws_config ? module.aws_config[0].config_bucket_id : null
}

output "aws_config_bucket_arn" {
  description = "ARN of the Config history bucket."
  value       = var.enable_aws_config ? module.aws_config[0].config_bucket_arn : null
}

output "aws_config_kms_key_arn" {
  description = "ARN of the customer-managed CMK encrypting Config history at rest."
  value       = var.enable_aws_config ? module.aws_config[0].config_kms_key_arn : null
}

output "aws_config_recorder_role_arn" {
  description = "ARN of the IAM role Config assumes."
  value       = var.enable_aws_config ? module.aws_config[0].iam_role_arn : null
}

# ---------- threat-detection ------------------------------------------

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector. Null when threat-detection is disabled or guardduty is opted out."
  value       = var.enable_threat_detection ? module.threat_detection[0].guardduty_detector_id : null
}

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer. Null when threat-detection is disabled or analyzer is opted out."
  value       = var.enable_threat_detection ? module.threat_detection[0].access_analyzer_arn : null
}

# ---------- alerts ----------------------------------------------------

output "alerts_topic_arn" {
  description = "ARN of the security alerts SNS topic. Downstream stacks fan their own alarms into this topic by attaching CloudWatch alarms / EventBridge targets to it."
  value       = var.enable_alerts ? module.alerts[0].topic_arn : null
}

output "alerts_kms_key_arn" {
  description = "ARN of the customer-managed CMK encrypting messages on the alerts topic."
  value       = var.enable_alerts ? module.alerts[0].kms_key_arn : null
}

# ---------- operator-role ---------------------------------------------

output "operator_role_arn" {
  description = "ARN of the operator role. Humans assume this with MFA via `aws sts assume-role`. Null when operator-role is disabled."
  value       = var.enable_operator_role ? module.operator_role[0].role_arn : null
}

output "operator_role_name" {
  description = "Name of the operator role."
  value       = var.enable_operator_role ? module.operator_role[0].role_name : null
}
