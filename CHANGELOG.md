# Changelog

## [v0.2.2](https://gitlab.com/phpboyscout/iac/terraform-aws-security-baseline/-/releases/v0.2.2)

[Compare to previous version](https://gitlab.com/phpboyscout/iac/terraform-aws-security-baseline/-/compare/v0.2.1...v0.2.2)

### Bug Fixes

- **ci**: publish on tag from a real stage, not .post ([1f9191d](https://gitlab.com/phpboyscout/iac/terraform-aws-security-baseline/-/commit/1f9191d848189a65eb9099ca6de38ec677afde8f))

## [v0.2.1](https://gitlab.com/phpboyscout/iac/terraform-aws-security-baseline/-/releases/v0.2.1)

[Compare to previous version](https://gitlab.com/phpboyscout/iac/terraform-aws-security-baseline/-/compare/v0.2.0...v0.2.1)

### Bug Fixes

- guard workflow dedup rule so release tag pipelines fire ([600588e](https://gitlab.com/phpboyscout/iac/terraform-aws-security-baseline/-/commit/600588e729d337d474bfab1fee4f7f5f38c89d74))

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-1.0 note: while the major version is `0`, minor version bumps may contain
breaking changes to the module's public input/output surface.

## [Unreleased]

## [0.2.0] - 2026-05-20

### Added

- Root inputs **`enable_guardduty`** and **`enable_securityhub`** (bool,
  default `true`) — granular toggles passing through to the existing
  `threat-detection` sub-module variables. Lets a consumer keep Access
  Analyzer running while skipping GuardDuty or Security Hub
  individually — for example while an AWS account's first-time service
  activation is pending and `SubscriptionRequiredException` would
  block the apply. Behaviour-preserving defaults; ignored when
  `enable_threat_detection = false`.

## [0.1.1] - 2026-05-19

### Fixed

- `alerts` sub-module — the SNS topic policy's `AllowAccountFullControl`
  statement used `actions = ["sns:*"]`. An SNS topic *resource* policy
  may contain only topic-scoped actions; `sns:*` pulls in account-level
  actions (`sns:CreateTopic`, `sns:ListTopics`, …), so applying the
  policy failed with `InvalidParameter: Policy statement action out of
  service scope`. The statement now lists the eight topic-scoped
  actions explicitly — the set AWS's own default topic policy grants.

## [0.1.0] - 2026-05-09

### Added

- Initial repository scaffolding: licence, README, CLAUDE.md, SECURITY
  policy, Zensical docs site, CI workflows, branch-protection rulesets,
  justfile task runner, pre-commit hooks, tflint config, master spec at
  `docs/development/specs/2026-05-06-security-baseline-v0.1.md`.
- `account-hardening` sub-module — IAM password policy (sensible
  production defaults; per-field overridable via the typed
  `password_policy` object), S3 account-wide public-access block, EBS
  default encryption with a customer-managed CMK, optional adoption of
  the IAM account alias.
- `audit-logging` sub-module — multi-region CloudTrail with log-file
  validation; hand-rolled KMS-encrypted log archive bucket with
  `prevent_destroy`, versioning, TLS-only / SSE-KMS-only bucket policy,
  lifecycle (STANDARD_IA at 90d, GLACIER_IR at 180d, expire at
  `var.log_retention_days` — default 730).
- `aws-config` sub-module — Config recorder, delivery channel, and
  hand-rolled KMS-encrypted history bucket with the same posture as
  the audit log bucket. AWS-managed `service-role/AWS_ConfigRole`
  attached to the recorder role.
- `threat-detection` sub-module — GuardDuty detector (FIFTEEN_MINUTES
  publishing frequency); Security Hub with explicit standards
  subscriptions (defaults: AWS Foundational Security Best Practices
  v1.0.0 + CIS AWS Foundations Benchmark v3.0.0; PCI DSS and CIS v1.4
  available opt-in); IAM Access Analyzer (account-scoped). Each
  service has its own `enable_*` toggle for à la carte use.
- `alerts` sub-module — KMS-encrypted SNS topic, email subscription,
  and four EventBridge rules: GuardDuty findings of severity ≥ 7,
  Security Hub HIGH/CRITICAL findings (excluding GuardDuty-sourced to
  avoid duplicates), root-account console sign-in, root-account API
  calls.
- `operator-role` sub-module — `InfraAdmin` role with MFA-required
  trust policy (`aws:MultiFactorAuthPresent` + `aws:MultiFactorAuthAge`
  conditions); region-restriction inline policy (Deny with `NotAction`
  carve-outs over the configurable `globally_scoped_actions` list);
  AWS-managed `AdministratorAccess` attached by default, toggleable
  off in favour of narrower policies passed via `additional_policy_arns`.
- Root composition — 14 inputs (4 required, 10 with smart defaults).
  Each sub-module gated by its own `enable_*` toggle so callers can
  compose à la carte. `var.tags` propagated through every sub-module.
  Naming defaults derive from `project_name` + `account_id`; override
  via the individual `*_name` inputs to break the convention. Outputs
  re-export the keys downstream consumers need (KMS ARNs, bucket ARNs,
  alerts topic ARN, operator role ARN, etc.).
- `examples/minimal/` — runnable smallest-possible caller, used as
  both consumer-facing reference and CI smoke test.

### Fixed

- The `account-hardening` sub-module originally declared an `import {}`
  block to adopt an existing IAM account alias on first apply. OpenTofu
  only allows `import` blocks in the root module, so this caused root
  composition (and any caller wrapping the sub-module via
  `module "..." { ... }`) to fail validation. The block was removed;
  alias adoption is now a documented caller-side recipe — consumers
  drop the `import` block in their own root module.
- CI lint / scan corrections: dropped unused `var.region` from
  `aws-config` and `alerts` sub-modules (tflint), added `checkov:skip`
  annotations with rationale on the password-policy `optional()`
  defaults, the CloudTrail trail (no SNS / no CloudWatch Logs by
  design), the operator-role admin attachment, and the count-gated
  GuardDuty detector.

### Documentation

- All seven module READMEs (root + six sub-modules) carry
  terraform-docs auto-injected inputs / outputs / resources tables;
  CI gates on drift via `terraform-docs/gh-actions@v1` with
  `fail-on-diff: true`.
- Master spec brought into sync with the as-built implementation: D3
  records the per-sub-module hand-roll rationale, D4 reflects the
  caller-side alias-adoption recipe, root inputs / outputs tables
  enumerate the actual shipped surface.
