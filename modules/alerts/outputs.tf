output "topic_arn" {
  description = "ARN of the security alerts SNS topic. Downstream stacks fan their own alarms into this topic by attaching their CloudWatch alarms / EventBridge targets to it."
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  description = "Name of the alerts topic."
  value       = aws_sns_topic.this.name
}

output "kms_key_arn" {
  description = "ARN of the customer-managed CMK encrypting messages on the alerts topic."
  value       = aws_kms_key.sns.arn
}

output "kms_alias_name" {
  description = "Full alias of the SNS-encryption CMK (with `alias/` prefix)."
  value       = aws_kms_alias.sns.name
}

output "subscription_pending_confirmation" {
  description = "Reminder that the email subscription requires manual confirmation by the recipient on first apply. Always true at apply time; AWS confirms out-of-band."
  value       = "Check ${var.alerts_email} for the AWS confirmation email and click the link. The subscription will not deliver until confirmed."
}
