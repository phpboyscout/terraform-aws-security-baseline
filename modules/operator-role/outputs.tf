output "role_arn" {
  description = "ARN of the operator role. Humans assume this with MFA via `aws sts assume-role` (or, more commonly, an SSO-style helper)."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the operator role."
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "Unique identifier of the operator role (e.g. for use in trust conditions on resources granted to this role)."
  value       = aws_iam_role.this.unique_id
}

output "allowed_regions" {
  description = "Regions in which this role can operate (region restriction). Empty list means no restriction is in effect."
  value       = local.effective_allowed_regions
}

output "region_restriction_enabled" {
  description = "Whether the region-restriction inline policy is attached."
  value       = local.region_restriction_enabled
}
