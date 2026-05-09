# `audit-logging`

Multi-region CloudTrail trail + KMS-encrypted S3 log archive bucket.
Hand-rolled (no upstream module) — the gnarly bits (CloudTrail
service-principal access in the bucket and KMS policies) are short
enough to keep direct control over, and we want the same
`prevent_destroy` + TLS-only / SSE-KMS-only posture the bootstrap
state bucket has.

## What you get

- `aws_cloudtrail` — multi-region by default, log-file validation
  on, captures global service events.
- `aws_kms_key` + `aws_kms_alias` — customer CMK encrypting log
  files at rest. Rotation on; 30-day deletion window.
- `aws_s3_bucket` — log archive bucket with versioning, SSE-KMS,
  public-access block, BucketOwnerEnforced, lifecycle (multipart-
  abort + transitions to STANDARD_IA at 90 days / GLACIER_IR at
  180 days, expire at `var.log_retention_days`), TLS-only bucket
  policy, and `prevent_destroy = true`.

## Usage

```hcl
module "audit_logging" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline//modules/audit-logging?ref=v0.1.0"

  account_id      = "049815585546"
  region          = "eu-west-2"
  log_bucket_name = "phpboyscout-audit-logs-049815585546"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

The trail's name defaults to `audit-logs`; override with `var.trail_name`
if you need to coexist with another trail.

## Retention default

`var.log_retention_days` defaults to **730 (two years)**, per the
master spec's open-question resolution. Compliance regimes
prescribe different floors:

- **SOC 2 / GDPR** — 1 year is a sensible default.
- **PCI-DSS** — 1 year online, 3 months immediately accessible.
- **HIPAA** — 6 years, with audit logs falling under that window.
- **Financial-services regulators (SEC 17a-4, FINRA 4511)** — 6 to
  7 years.

Override `log_retention_days` for stricter regimes; storage costs
scale linearly but Glacier-IR is cheap.

## CloudWatch Logs integration

Not included in v0.1. CloudTrail can additionally stream events to
CloudWatch Logs for real-time alerting (instead of, or in addition
to, the S3 archive). Future v0.2 expansion if the alerts sub-module
needs near-real-time event matching.

For now, the `alerts` sub-module wires EventBridge rules directly to
the CloudTrail event source on the default event bus — that path
fires within seconds of the API call without requiring CloudWatch
Logs.

## Why hand-rolled and not `terraform-aws-modules/cloudtrail`?

The upstream module is fine but bundles its own bucket creation
without the `prevent_destroy` lifecycle we want, and the bucket
policy it generates differs subtly from ours (no
`bucket-owner-full-control` ACL constraint, weaker source-ARN
condition). Net of those, hand-rolling adds maybe 50 lines but
gives us bit-for-bit identical posture to the state bucket from
`terraform-aws-bootstrap`. Worth the trade.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0, < 7.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudtrail.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_kms_alias.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_abort_incomplete_multipart_upload_days"></a> [abort\_incomplete\_multipart\_upload\_days](#input\_abort\_incomplete\_multipart\_upload\_days) | Days after which incomplete multipart uploads to the log bucket are aborted. Closes CKV\_AWS\_300. | `number` | `7` | no |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID. Used in service-principal source-ARN conditions on the log bucket policy. | `string` | n/a | yes |
| <a name="input_enable_log_file_validation"></a> [enable\_log\_file\_validation](#input\_enable\_log\_file\_validation) | Whether CloudTrail produces signed digests so log integrity can be verified after the fact. Recommended. | `bool` | `true` | no |
| <a name="input_include_global_service_events"></a> [include\_global\_service\_events](#input\_include\_global\_service\_events) | Whether to log events for global services (IAM, CloudFront, Route53, etc.). Recommended. | `bool` | `true` | no |
| <a name="input_is_multi_region_trail"></a> [is\_multi\_region\_trail](#input\_is\_multi\_region\_trail) | Whether the CloudTrail trail captures events from all AWS regions. Recommended; only disable for cost-sensitive single-region deployments. | `bool` | `true` | no |
| <a name="input_log_bucket_name"></a> [log\_bucket\_name](#input\_log\_bucket\_name) | S3 bucket name for the CloudTrail log archive. Must be globally unique. Convention: `<project>-audit-logs-<account_id>`. | `string` | n/a | yes |
| <a name="input_log_kms_alias"></a> [log\_kms\_alias](#input\_log\_kms\_alias) | Alias for the log-encryption CMK, without the `alias/` prefix. | `string` | `"audit-logs"` | no |
| <a name="input_log_kms_deletion_window_in_days"></a> [log\_kms\_deletion\_window\_in\_days](#input\_log\_kms\_deletion\_window\_in\_days) | Days the log-encryption CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30. | `number` | `30` | no |
| <a name="input_log_kms_enable_key_rotation"></a> [log\_kms\_enable\_key\_rotation](#input\_log\_kms\_enable\_key\_rotation) | Whether AWS automatically rotates the log-encryption CMK's key material annually. | `bool` | `true` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Days noncurrent log object versions are retained before expiring. Defaults to 730 (two years), per the master spec's OQ4 resolution. | `number` | `730` | no |
| <a name="input_region"></a> [region](#input\_region) | Region the log bucket lives in. Surfaced via outputs so consuming stacks can reference the bucket's home region. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |
| <a name="input_trail_name"></a> [trail\_name](#input\_trail\_name) | Name of the CloudTrail trail. | `string` | `"audit-logs"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_log_bucket_arn"></a> [log\_bucket\_arn](#output\_log\_bucket\_arn) | ARN of the log bucket. |
| <a name="output_log_bucket_id"></a> [log\_bucket\_id](#output\_log\_bucket\_id) | Name of the S3 bucket holding CloudTrail logs. |
| <a name="output_log_bucket_region"></a> [log\_bucket\_region](#output\_log\_bucket\_region) | Region the log bucket lives in. |
| <a name="output_log_kms_alias_name"></a> [log\_kms\_alias\_name](#output\_log\_kms\_alias\_name) | Full alias of the log-encryption CMK (with `alias/` prefix). |
| <a name="output_log_kms_key_arn"></a> [log\_kms\_key\_arn](#output\_log\_kms\_key\_arn) | ARN of the customer-managed CMK encrypting CloudTrail logs at rest. |
| <a name="output_log_kms_key_id"></a> [log\_kms\_key\_id](#output\_log\_kms\_key\_id) | Key ID of the log-encryption CMK. |
| <a name="output_trail_arn"></a> [trail\_arn](#output\_trail\_arn) | ARN of the CloudTrail trail. |
| <a name="output_trail_home_region"></a> [trail\_home\_region](#output\_trail\_home\_region) | Home region of the CloudTrail trail. Identical to `var.region`. |
| <a name="output_trail_name"></a> [trail\_name](#output\_trail\_name) | Name of the CloudTrail trail. |
<!-- END_TF_DOCS -->
