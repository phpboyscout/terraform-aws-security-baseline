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
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->
