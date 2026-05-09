output "ebs_default_kms_key_arn" {
  description = "ARN of the customer-managed CMK used as the EBS default-encryption key."
  value       = module.security_baseline.ebs_default_kms_key_arn
}

output "audit_log_bucket_arn" {
  description = "ARN of the audit log bucket."
  value       = module.security_baseline.audit_log_bucket_arn
}

output "audit_trail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = module.security_baseline.audit_trail_arn
}

output "aws_config_bucket_arn" {
  description = "ARN of the AWS Config history bucket."
  value       = module.security_baseline.aws_config_bucket_arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector."
  value       = module.security_baseline.guardduty_detector_id
}

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer."
  value       = module.security_baseline.access_analyzer_arn
}

output "alerts_topic_arn" {
  description = "ARN of the security alerts SNS topic. Downstream stacks fan their own alarms in by attaching CloudWatch alarms or EventBridge targets to this ARN."
  value       = module.security_baseline.alerts_topic_arn
}

output "operator_role_arn" {
  description = "ARN of the operator role. Humans assume this with MFA via `aws sts assume-role`."
  value       = module.security_baseline.operator_role_arn
}
