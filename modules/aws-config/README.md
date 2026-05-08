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
  region             = "eu-west-2"
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
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->
