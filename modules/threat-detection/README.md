# `threat-detection`

GuardDuty detector + Security Hub with explicit standards subscriptions
+ IAM Access Analyzer. Each service has its own `enable_*` toggle so
the sub-module can be used à la carte.

## What you get by default

- `aws_guardduty_detector` — enabled, FIFTEEN_MINUTES finding-
  publishing frequency. No optional features (Malware Protection,
  EKS, RDS, Lambda, S3) — those are workload-dependent and carry
  per-feature cost. Callers that need them add
  `aws_guardduty_detector_feature` resources separately.
- `aws_securityhub_account` — enabled, `enable_default_standards =
  false` (we manage subscriptions explicitly), `control_finding_generator
  = SECURITY_CONTROL` (consolidated findings across standards).
- `aws_securityhub_standards_subscription` — one per entry in
  `var.securityhub_standards`. Default: AWS Foundational Security
  Best Practices + CIS AWS Foundations Benchmark v3.0.
- `aws_accessanalyzer_analyzer` — single account-scoped analyzer.

## Usage

```hcl
module "threat_detection" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline//modules/threat-detection?ref=v0.1.0"

  region = "eu-west-2"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

## Security Hub standards

| Key | Resource | Notes |
|---|---|---|
| `fsbp` | AWS Foundational Security Best Practices v1.0.0 | Default. Broadly applicable. |
| `cis-v3` | CIS AWS Foundations Benchmark v3.0.0 | Default. Current CIS revision. |
| `cis-v1.4` | CIS AWS Foundations Benchmark v1.4.0 | Deprecated; use cis-v3 unless audit constraints require v1.4 specifically. |
| `pci-dss` | PCI DSS v3.2.1 | Workload-specific; opt-in only when the account hosts cardholder data. |

The mapping from key to standards ARN lives in `main.tf`'s `locals`
block. When AWS publishes a new standard or revs a major version, add
the new entry there.

## Multi-region note

In v0.1, this module is designed to run in the **primary region only**.
For multi-region threat detection, deploy the module to each region
with `enable_access_analyzer = false` on non-primary regions (the
analyzer is per-region; running it everywhere is rarely worthwhile).

GuardDuty multi-region detector replication is a v0.2 expansion —
when added, it will go in this sub-module rather than requiring
multiple module deployments.

## Cost notes

- **GuardDuty** — pricing scales with VPC Flow Logs, CloudTrail event
  volume, and DNS query volume. For an empty account, $0.50–$2/month
  is typical; for a busy production account, much more.
- **Security Hub** — first 10,000 finding-ingestion events per month
  per region are free; beyond that, $0.0003/event. Standards-control
  evaluations are free.
- **Access Analyzer** — free for the basic external-access analyzer
  type used here. Unused-Access Analyzer (paid tier) is out of scope
  for v0.1.

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
| [aws_accessanalyzer_analyzer.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer) | resource |
| [aws_guardduty_detector.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector) | resource |
| [aws_securityhub_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_account) | resource |
| [aws_securityhub_standards_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/securityhub_standards_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_analyzer_name"></a> [access\_analyzer\_name](#input\_access\_analyzer\_name) | Name of the analyzer. | `string` | `"default-account"` | no |
| <a name="input_access_analyzer_type"></a> [access\_analyzer\_type](#input\_access\_analyzer\_type) | Scope of the analyzer. `ACCOUNT` analyses just this account; `ORGANIZATION` requires AWS Organizations and analyses all member accounts (out of scope for single-account v0.1 setups). | `string` | `"ACCOUNT"` | no |
| <a name="input_enable_access_analyzer"></a> [enable\_access\_analyzer](#input\_enable\_access\_analyzer) | Whether to provision an IAM Access Analyzer. | `bool` | `true` | no |
| <a name="input_enable_guardduty"></a> [enable\_guardduty](#input\_enable\_guardduty) | Whether to provision a GuardDuty detector in this region. | `bool` | `true` | no |
| <a name="input_enable_securityhub"></a> [enable\_securityhub](#input\_enable\_securityhub) | Whether to enable Security Hub in this region. | `bool` | `true` | no |
| <a name="input_guardduty_finding_publishing_frequency"></a> [guardduty\_finding\_publishing\_frequency](#input\_guardduty\_finding\_publishing\_frequency) | How often GuardDuty exports updated findings to EventBridge. One of `FIFTEEN_MINUTES`, `ONE_HOUR`, `SIX_HOURS`. Faster = more responsive alerting; cost is identical. | `string` | `"FIFTEEN_MINUTES"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region the detector / hub / analyzer run in. Used in Security Hub standards ARNs. | `string` | n/a | yes |
| <a name="input_securityhub_control_finding_generator"></a> [securityhub\_control\_finding\_generator](#input\_securityhub\_control\_finding\_generator) | How Security Hub generates findings for controls. `SECURITY_CONTROL` (recommended; consolidated across standards) or `STANDARD_CONTROL` (legacy; one finding per standard per control). | `string` | `"SECURITY_CONTROL"` | no |
| <a name="input_securityhub_enable_default_standards"></a> [securityhub\_enable\_default\_standards](#input\_securityhub\_enable\_default\_standards) | Whether to let AWS auto-subscribe Security Hub to its current set of default standards. Default false — we explicitly manage subscriptions via `securityhub_standards` so what's enabled is deterministic. | `bool` | `false` | no |
| <a name="input_securityhub_standards"></a> [securityhub\_standards](#input\_securityhub\_standards) | Security Hub standards to subscribe to. Use the keys from the supported set: `fsbp` (AWS Foundational Security Best Practices), `cis-v3` (CIS AWS Foundations Benchmark v3.0), `cis-v1.4` (CIS v1.4 — deprecated, prefer v3), `pci-dss` (PCI DSS — workload-specific, opt-in only). | `set(string)` | <pre>[<br/>  "fsbp",<br/>  "cis-v3"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_analyzer_arn"></a> [access\_analyzer\_arn](#output\_access\_analyzer\_arn) | ARN of the IAM Access Analyzer. Null when `enable_access_analyzer = false`. |
| <a name="output_access_analyzer_name"></a> [access\_analyzer\_name](#output\_access\_analyzer\_name) | Name of the analyzer. Null when `enable_access_analyzer = false`. |
| <a name="output_guardduty_detector_arn"></a> [guardduty\_detector\_arn](#output\_guardduty\_detector\_arn) | ARN of the GuardDuty detector. Null when `enable_guardduty = false`. |
| <a name="output_guardduty_detector_id"></a> [guardduty\_detector\_id](#output\_guardduty\_detector\_id) | ID of the GuardDuty detector. Null when `enable_guardduty = false`. |
| <a name="output_securityhub_account_id"></a> [securityhub\_account\_id](#output\_securityhub\_account\_id) | Identifier of the enabled Security Hub account. Null when `enable_securityhub = false`. |
| <a name="output_securityhub_subscribed_standards"></a> [securityhub\_subscribed\_standards](#output\_securityhub\_subscribed\_standards) | Map of subscribed standard key → standards subscription ARN. |
<!-- END_TF_DOCS -->
