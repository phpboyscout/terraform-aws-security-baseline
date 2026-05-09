# terraform-aws-security-baseline

> ⚠️ Pre-1.0. API will move. Pin to a tag, not a branch.

Opinionated AWS security baseline for [OpenTofu](https://opentofu.org/) /
Terraform. Hardens an AWS account *post-bootstrap*: account-level hygiene,
audit logging, AWS Config, threat detection, alerts, and an MFA-required
human operator role. Sibling to [`terraform-aws-bootstrap`](https://github.com/phpboyscout/terraform-aws-bootstrap),
which prepares the bare minimum needed for the *next* `tofu apply`.

## What's in scope

Six sub-modules behind a thin root:

1. **`account-hardening`** — IAM password policy, S3 account-wide
   public-access block, EBS default encryption + customer-managed CMK.
   Optional IAM account alias adoption (off by default).
2. **`audit-logging`** — multi-region CloudTrail with log-file
   validation; KMS-encrypted log bucket with `prevent_destroy`,
   TLS-only / SSE-KMS-only bucket policy.
3. **`aws-config`** — Config recorder + delivery channel + history
   bucket. Records every supported resource type by default.
4. **`threat-detection`** — GuardDuty detector (primary region in
   v0.1), Security Hub with FSBP + CIS v3.0 standards, IAM Access
   Analyzer.
5. **`alerts`** — SNS topic + email subscription + EventBridge rules
   for HIGH/CRITICAL GuardDuty + Security Hub findings, plus root
   login + root API usage alarms.
6. **`operator-role`** — `InfraAdmin` role with MFA-required trust
   policy and a configurable region-restriction inline policy
   (default: primary region only, with carve-outs for global services).

Each sub-module is gated by an `enable_*` toggle so callers can compose
the baseline à la carte (e.g. audit-logging + alerts only, for accounts
where GuardDuty cost isn't yet warranted).

## What's deliberately NOT in scope

Bootstrap (state backend, OIDC, automation role) — that's
[`terraform-aws-bootstrap`](https://github.com/phpboyscout/terraform-aws-bootstrap).
Workload-specific resources — each gets its own consumer-side stack.
Multi-account Organizations setup, IAM Identity Center / SSO, WAF,
Inspector v2, Macie, Detective — see the master spec for the full
out-of-scope list and rationale.

## Quick start

```hcl
module "security_baseline" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline?ref=v0.1.0"

  account_id   = "049815585546"
  region       = "eu-west-2"
  project_name = "phpboyscout"
  alerts_email = "aws@phpboyscout.uk"

  # Default settings: all six sub-modules enabled, primary-region-only
  # restriction on the operator role, 730-day audit log retention.

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

See [`examples/minimal/`](./examples/minimal/) for a complete, runnable
caller.

## Conventions

- **Tags propagated everywhere.** Every taggable resource accepts and
  applies `var.tags`. See `docs/development/engineering-standards.md`.
- **OpenTofu-first.** Tested with OpenTofu (`.opentofu-version`).
  Compatible with Terraform ≥ 1.10.
- **Hand-rolled, not framework-wrapped.** All six sub-modules use
  AWS resources directly rather than `terraform-aws-modules/*` /
  Cloud Posse / Control Tower wraps. Each sub-module README has a
  "Why hand-rolled?" section recording the trade-off (mostly:
  upstream wraps either bundle assumptions we don't want, or are
  thin enough that wrapping is more code, not less).
- **No labels conventions.** No `context` input, no Atmos. Plain
  inputs, plain outputs.

## Documentation

The full microsite — including the master spec, per-sub-module specs,
and design rationale — is at
[phpboyscout.uk/terraform-aws-security-baseline/](https://phpboyscout.uk/terraform-aws-security-baseline/)
(once the first release is tagged).

## Roadmap

- **v0.1** — AWS only, six sub-modules described above.
- **v0.2** — Multi-region GuardDuty (deferred from v0.1 per the master
  spec's open-questions resolution).
- **Future** — sibling repos `terraform-gcp-security-baseline` and
  `terraform-azure-security-baseline` with the same shape so callers
  can swap providers cleanly.

## Inputs and outputs

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

No providers.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_alias"></a> [account\_alias](#input\_account\_alias) | IAM account alias to import and manage. Required when `manage_account_alias = true`. | `string` | `null` | no |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID this module operates against. Threaded through every sub-module that needs it for principal scoping. | `string` | n/a | yes |
| <a name="input_alerts_email"></a> [alerts\_email](#input\_alerts\_email) | Email address subscribed to the alerts SNS topic. Required even when `enable_alerts = false` to keep the signature stable; ignored in that case. AWS will send a confirmation email on first apply. | `string` | n/a | yes |
| <a name="input_allowed_regions"></a> [allowed\_regions](#input\_allowed\_regions) | Regions the operator role is permitted to operate in. Null defaults to `[var.region]` (single-region restriction). Pass a wider list for multi-region setups, or `[]` to disable the restriction entirely. | `list(string)` | `null` | no |
| <a name="input_audit_retention_days"></a> [audit\_retention\_days](#input\_audit\_retention\_days) | Days noncurrent log object versions are retained before expiring. Applied to both the audit log bucket and the Config history bucket. Default 730 (two years) per the master spec's OQ4 resolution; override for stricter compliance regimes. | `number` | `730` | no |
| <a name="input_config_bucket_name"></a> [config\_bucket\_name](#input\_config\_bucket\_name) | Override for the Config history bucket name. Defaults to `<project_name>-config-<account_id>`. | `string` | `null` | no |
| <a name="input_enable_account_hardening"></a> [enable\_account\_hardening](#input\_enable\_account\_hardening) | Whether to provision the account-hardening sub-module (password policy, S3 public-access block, EBS default encryption, optional alias adoption). | `bool` | `true` | no |
| <a name="input_enable_alerts"></a> [enable\_alerts](#input\_enable\_alerts) | Whether to provision the alerts sub-module (SNS topic + email subscription + EventBridge rules). | `bool` | `true` | no |
| <a name="input_enable_audit_logging"></a> [enable\_audit\_logging](#input\_enable\_audit\_logging) | Whether to provision the audit-logging sub-module (multi-region CloudTrail + KMS-encrypted log bucket). | `bool` | `true` | no |
| <a name="input_enable_aws_config"></a> [enable\_aws\_config](#input\_enable\_aws\_config) | Whether to provision the aws-config sub-module (Config recorder + delivery channel + history bucket). | `bool` | `true` | no |
| <a name="input_enable_operator_role"></a> [enable\_operator\_role](#input\_enable\_operator\_role) | Whether to provision the operator-role sub-module (InfraAdmin with MFA-required trust + region-restriction policy). | `bool` | `true` | no |
| <a name="input_enable_threat_detection"></a> [enable\_threat\_detection](#input\_enable\_threat\_detection) | Whether to provision the threat-detection sub-module (GuardDuty + Security Hub + Access Analyzer). | `bool` | `true` | no |
| <a name="input_log_bucket_name"></a> [log\_bucket\_name](#input\_log\_bucket\_name) | Override for the audit log bucket name. Defaults to `<project_name>-audit-logs-<account_id>`. S3 names are globally unique. | `string` | `null` | no |
| <a name="input_manage_account_alias"></a> [manage\_account\_alias](#input\_manage\_account\_alias) | Whether the account-hardening sub-module takes over the IAM account alias. Default false (caller may already manage it elsewhere). When true, `account_alias` must be the existing value. | `bool` | `false` | no |
| <a name="input_operator_role_name"></a> [operator\_role\_name](#input\_operator\_role\_name) | Name of the operator role. | `string` | `"InfraAdmin"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Short, kebab-case identifier used to derive default resource names (audit log bucket, Config history bucket). Override the individual `*_name` inputs to break this convention. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Primary region. The audit log + Config history buckets live here; GuardDuty / Security Hub / Access Analyzer run here; the operator role's region restriction defaults to this region only. | `string` | n/a | yes |
| <a name="input_securityhub_standards"></a> [securityhub\_standards](#input\_securityhub\_standards) | Security Hub standards to subscribe to. See `modules/threat-detection/variables.tf` for the supported set. | `set(string)` | <pre>[<br/>  "fsbp",<br/>  "cis-v3"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource the sub-modules create. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_analyzer_arn"></a> [access\_analyzer\_arn](#output\_access\_analyzer\_arn) | ARN of the IAM Access Analyzer. Null when threat-detection is disabled or analyzer is opted out. |
| <a name="output_account_alias"></a> [account\_alias](#output\_account\_alias) | IAM account alias managed by the account-hardening sub-module. Null when account-hardening is disabled or `manage_account_alias = false`. |
| <a name="output_alerts_kms_key_arn"></a> [alerts\_kms\_key\_arn](#output\_alerts\_kms\_key\_arn) | ARN of the customer-managed CMK encrypting messages on the alerts topic. |
| <a name="output_alerts_topic_arn"></a> [alerts\_topic\_arn](#output\_alerts\_topic\_arn) | ARN of the security alerts SNS topic. Downstream stacks fan their own alarms into this topic by attaching CloudWatch alarms / EventBridge targets to it. |
| <a name="output_audit_log_bucket_arn"></a> [audit\_log\_bucket\_arn](#output\_audit\_log\_bucket\_arn) | ARN of the audit log bucket. |
| <a name="output_audit_log_bucket_id"></a> [audit\_log\_bucket\_id](#output\_audit\_log\_bucket\_id) | Name of the S3 bucket holding CloudTrail logs. |
| <a name="output_audit_log_kms_key_arn"></a> [audit\_log\_kms\_key\_arn](#output\_audit\_log\_kms\_key\_arn) | ARN of the customer-managed CMK encrypting CloudTrail logs at rest. |
| <a name="output_audit_trail_arn"></a> [audit\_trail\_arn](#output\_audit\_trail\_arn) | ARN of the CloudTrail trail. |
| <a name="output_aws_config_bucket_arn"></a> [aws\_config\_bucket\_arn](#output\_aws\_config\_bucket\_arn) | ARN of the Config history bucket. |
| <a name="output_aws_config_bucket_id"></a> [aws\_config\_bucket\_id](#output\_aws\_config\_bucket\_id) | Name of the S3 bucket holding AWS Config history. |
| <a name="output_aws_config_kms_key_arn"></a> [aws\_config\_kms\_key\_arn](#output\_aws\_config\_kms\_key\_arn) | ARN of the customer-managed CMK encrypting Config history at rest. |
| <a name="output_aws_config_recorder_role_arn"></a> [aws\_config\_recorder\_role\_arn](#output\_aws\_config\_recorder\_role\_arn) | ARN of the IAM role Config assumes. |
| <a name="output_ebs_default_kms_key_arn"></a> [ebs\_default\_kms\_key\_arn](#output\_ebs\_default\_kms\_key\_arn) | ARN of the customer-managed CMK used as the EBS default-encryption key. Null when account-hardening is disabled. |
| <a name="output_guardduty_detector_id"></a> [guardduty\_detector\_id](#output\_guardduty\_detector\_id) | ID of the GuardDuty detector. Null when threat-detection is disabled or guardduty is opted out. |
| <a name="output_operator_role_arn"></a> [operator\_role\_arn](#output\_operator\_role\_arn) | ARN of the operator role. Humans assume this with MFA via `aws sts assume-role`. Null when operator-role is disabled. |
| <a name="output_operator_role_name"></a> [operator\_role\_name](#output\_operator\_role\_name) | Name of the operator role. |
<!-- END_TF_DOCS -->

## License

MIT — see [LICENSE](./LICENSE).
