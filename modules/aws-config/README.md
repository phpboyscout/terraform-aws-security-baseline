# `aws-config`

AWS Config recorder + delivery channel + KMS-encrypted history bucket.
Same posture as `audit-logging` (hand-rolled bucket with
`prevent_destroy` + TLS-only + SSE-KMS-only policy; customer-managed
CMK; bucket and KMS policies scoped to the Config service principal).

## What you get

- `aws_config_configuration_recorder` — records all supported resource
  types; includes global resources by default.
- `aws_config_delivery_channel` — daily snapshots to the history
  bucket (configurable via `snapshot_delivery_frequency`).
- `aws_config_configuration_recorder_status` — enables the recorder.
- `aws_iam_role` + attachment of the AWS-managed
  `service-role/AWS_ConfigRole` policy.
- `aws_kms_key` + `aws_kms_alias` — customer CMK encrypting history
  at rest. Rotation on; 30-day deletion window.
- `aws_s3_bucket` — history archive bucket with the same hardening
  as the audit-logging log bucket: versioning, SSE-KMS, public-access
  block, BucketOwnerEnforced, lifecycle, TLS-only policy,
  `prevent_destroy = true`.

## Usage

```hcl
module "aws_config" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline//modules/aws-config?ref=v0.1.0"

  account_id         = "049815585546"
  config_bucket_name = "phpboyscout-config-049815585546"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

## Multi-region note

`include_global_resource_types` defaults to `true`. **Only one region's
recorder should have this enabled** — running in multiple regions
duplicates the global-resource snapshot cost without adding signal.
For deployments that record in multiple regions, set this to `false`
on every region except the primary.

## Cost considerations

AWS Config is priced per configuration item recorded. For a small
account, this typically lands at low single-digit dollars per month.
For larger accounts (many EC2 instances, frequent IAM churn), it can
run higher — review the AWS Config pricing page.

To reduce cost without disabling Config entirely:
- Switch to `EXCLUSION_BY_RESOURCE_TYPES` (out of scope for v0.1; use
  the resource directly) and exclude high-churn types like
  `AWS::EC2::Instance`.
- Increase `snapshot_delivery_frequency` to `TwentyFour_Hours` (already
  the default).

## Why hand-rolled?

`terraform-aws-modules/config/aws` exists and works, but it doesn't
manage the history bucket — it expects you to pass an existing bucket
ID. We'd be hand-rolling the bucket either way (matching audit-
logging's posture). At that point the upstream module's value is
maybe 30 lines of recorder + delivery-channel + role-policy
boilerplate. Not worth the dependency. Same logic as audit-logging.

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
| [aws_config_configuration_recorder.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder) | resource |
| [aws_config_configuration_recorder_status.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status) | resource |
| [aws_config_delivery_channel.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_delivery_channel) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_abort_incomplete_multipart_upload_days"></a> [abort\_incomplete\_multipart\_upload\_days](#input\_abort\_incomplete\_multipart\_upload\_days) | Days after which incomplete multipart uploads to the history bucket are aborted. Closes CKV\_AWS\_300. | `number` | `7` | no |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID. Used in service-principal source-ARN conditions on the Config history bucket policy. | `string` | n/a | yes |
| <a name="input_config_bucket_name"></a> [config\_bucket\_name](#input\_config\_bucket\_name) | S3 bucket name for the AWS Config history archive. Must be globally unique. Convention: `<project>-config-<account_id>`. | `string` | n/a | yes |
| <a name="input_config_kms_alias"></a> [config\_kms\_alias](#input\_config\_kms\_alias) | Alias for the Config history-encryption CMK, without the `alias/` prefix. | `string` | `"aws-config"` | no |
| <a name="input_config_kms_deletion_window_in_days"></a> [config\_kms\_deletion\_window\_in\_days](#input\_config\_kms\_deletion\_window\_in\_days) | Days the Config CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30. | `number` | `30` | no |
| <a name="input_config_kms_enable_key_rotation"></a> [config\_kms\_enable\_key\_rotation](#input\_config\_kms\_enable\_key\_rotation) | Whether AWS automatically rotates the Config CMK's key material annually. | `bool` | `true` | no |
| <a name="input_delivery_channel_name"></a> [delivery\_channel\_name](#input\_delivery\_channel\_name) | Name of the Config delivery channel. | `string` | `"default"` | no |
| <a name="input_history_retention_days"></a> [history\_retention\_days](#input\_history\_retention\_days) | Days noncurrent Config history object versions are retained before expiring. Defaults to 730 (two years), matching audit-logging. | `number` | `730` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name of the IAM role Config assumes to record resources. | `string` | `"aws-config-recorder"` | no |
| <a name="input_include_global_resource_types"></a> [include\_global\_resource\_types](#input\_include\_global\_resource\_types) | Whether the recorder includes global resource types (IAM, CloudFront, Route53, etc.). Enable on the primary region only — running in multiple regions duplicates the global-resource cost without adding signal. | `bool` | `true` | no |
| <a name="input_recorder_name"></a> [recorder\_name](#input\_recorder\_name) | Name of the Config configuration recorder. | `string` | `"default"` | no |
| <a name="input_snapshot_delivery_frequency"></a> [snapshot\_delivery\_frequency](#input\_snapshot\_delivery\_frequency) | Frequency Config snapshots are delivered to the bucket. One of `One_Hour`, `Three_Hours`, `Six_Hours`, `Twelve_Hours`, `TwentyFour_Hours`. | `string` | `"TwentyFour_Hours"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_bucket_arn"></a> [config\_bucket\_arn](#output\_config\_bucket\_arn) | ARN of the Config history bucket. |
| <a name="output_config_bucket_id"></a> [config\_bucket\_id](#output\_config\_bucket\_id) | Name of the S3 bucket holding AWS Config history. |
| <a name="output_config_kms_alias_name"></a> [config\_kms\_alias\_name](#output\_config\_kms\_alias\_name) | Full alias of the Config history-encryption CMK (with `alias/` prefix). |
| <a name="output_config_kms_key_arn"></a> [config\_kms\_key\_arn](#output\_config\_kms\_key\_arn) | ARN of the customer-managed CMK encrypting Config history at rest. |
| <a name="output_delivery_channel_name"></a> [delivery\_channel\_name](#output\_delivery\_channel\_name) | Name of the Config delivery channel. |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the IAM role Config assumes to record resources. |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | Name of the IAM role Config assumes. |
| <a name="output_recorder_name"></a> [recorder\_name](#output\_recorder\_name) | Name of the Config configuration recorder. |
<!-- END_TF_DOCS -->
