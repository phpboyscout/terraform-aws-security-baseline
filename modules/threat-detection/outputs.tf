output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector. Null when `enable_guardduty = false`."
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : null
}

output "guardduty_detector_arn" {
  description = "ARN of the GuardDuty detector. Null when `enable_guardduty = false`."
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].arn : null
}

output "securityhub_account_id" {
  description = "Identifier of the enabled Security Hub account. Null when `enable_securityhub = false`."
  value       = var.enable_securityhub ? aws_securityhub_account.this[0].id : null
}

output "securityhub_subscribed_standards" {
  description = "Map of subscribed standard key → standards subscription ARN."
  value = var.enable_securityhub ? {
    for k, v in aws_securityhub_standards_subscription.this : k => v.id
  } : {}
}

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer. Null when `enable_access_analyzer = false`."
  value       = var.enable_access_analyzer ? aws_accessanalyzer_analyzer.this[0].arn : null
}

output "access_analyzer_name" {
  description = "Name of the analyzer. Null when `enable_access_analyzer = false`."
  value       = var.enable_access_analyzer ? aws_accessanalyzer_analyzer.this[0].analyzer_name : null
}
