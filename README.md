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
- **Upstream modules used selectively** for narrow, factual concerns
  (`terraform-aws-modules/cloudtrail`, `…/config`, `…/iam` for the
  operator role). Hand-rolled where wrapping adds no value.
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

## License

MIT — see [LICENSE](./LICENSE).
