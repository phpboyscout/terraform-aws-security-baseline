output "ebs_default_kms_key_arn" {
  description = "ARN of the customer-managed CMK used as the EBS default-encryption key."
  value       = aws_kms_key.ebs_default.arn
}

output "ebs_default_kms_key_id" {
  description = "Key ID of the EBS default-encryption CMK."
  value       = aws_kms_key.ebs_default.key_id
}

output "ebs_default_kms_alias_name" {
  description = "Full alias of the EBS default-encryption CMK (with `alias/` prefix)."
  value       = aws_kms_alias.ebs_default.name
}

output "account_alias" {
  description = "IAM account alias managed by this module. Null when `manage_account_alias = false`."
  value       = var.manage_account_alias ? aws_iam_account_alias.this[0].account_alias : null
}

output "password_policy_min_length" {
  description = "Minimum password length the IAM account password policy enforces. Useful for downstream documentation / Security Hub findings reconciliation."
  value       = aws_iam_account_password_policy.this.minimum_password_length
}
