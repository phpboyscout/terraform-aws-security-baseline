output "config_bucket_id" {
  description = "Name of the S3 bucket holding AWS Config history."
  value       = aws_s3_bucket.config.id
}

output "config_bucket_arn" {
  description = "ARN of the Config history bucket."
  value       = aws_s3_bucket.config.arn
}

output "config_kms_key_arn" {
  description = "ARN of the customer-managed CMK encrypting Config history at rest."
  value       = aws_kms_key.config.arn
}

output "config_kms_alias_name" {
  description = "Full alias of the Config history-encryption CMK (with `alias/` prefix)."
  value       = aws_kms_alias.config.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role Config assumes to record resources."
  value       = aws_iam_role.this.arn
}

output "iam_role_name" {
  description = "Name of the IAM role Config assumes."
  value       = aws_iam_role.this.name
}

output "recorder_name" {
  description = "Name of the Config configuration recorder."
  value       = aws_config_configuration_recorder.this.name
}

output "delivery_channel_name" {
  description = "Name of the Config delivery channel."
  value       = aws_config_delivery_channel.this.name
}
