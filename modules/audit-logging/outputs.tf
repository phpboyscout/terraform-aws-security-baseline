output "log_bucket_id" {
  description = "Name of the S3 bucket holding CloudTrail logs."
  value       = aws_s3_bucket.logs.id
}

output "log_bucket_arn" {
  description = "ARN of the log bucket."
  value       = aws_s3_bucket.logs.arn
}

output "log_bucket_region" {
  description = "Region the log bucket lives in."
  value       = var.region
}

output "log_kms_key_arn" {
  description = "ARN of the customer-managed CMK encrypting CloudTrail logs at rest."
  value       = aws_kms_key.logs.arn
}

output "log_kms_key_id" {
  description = "Key ID of the log-encryption CMK."
  value       = aws_kms_key.logs.key_id
}

output "log_kms_alias_name" {
  description = "Full alias of the log-encryption CMK (with `alias/` prefix)."
  value       = aws_kms_alias.logs.name
}

output "trail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.this.arn
}

output "trail_name" {
  description = "Name of the CloudTrail trail."
  value       = aws_cloudtrail.this.name
}

output "trail_home_region" {
  description = "Home region of the CloudTrail trail. Identical to `var.region`."
  value       = aws_cloudtrail.this.home_region
}
