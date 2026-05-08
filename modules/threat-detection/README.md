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
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->
