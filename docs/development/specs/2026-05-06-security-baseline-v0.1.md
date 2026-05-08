---
title: terraform-aws-security-baseline v0.1
description: Master spec for the second public reusable module — account hardening, audit logging, AWS Config, threat detection, alerts, and the human operator role.
status: approved
date: 2026-05-06
authors: [Matt Cockayne]
tags: [spec, master, security-baseline]
---

# Spec: terraform-aws-security-baseline v0.1

- **Repository:** `phpboyscout/terraform-aws-security-baseline` (to be created — parallel to `terraform-aws-bootstrap`)
- **Scope:** the public reusable module that hardens an AWS account *post-bootstrap*.
- **Consumed by:** `phpboyscout/infra/src/security-baseline/`.

## Summary

`terraform-aws-bootstrap` provisions the bare minimum needed for the
*next* `tofu apply` (state backend + GitHub OIDC + automation role +
nuke config). Once that's in place, the next layer is everything that
makes the account *safe to operate*: account-level hygiene, audit
logging, threat detection, alert wiring, and a human operator
identity.

We extract that layer as a separate module so it can be reused on
every AWS account we manage, and so the bootstrap module stays
minimal. Same shape as bootstrap (sub-modules behind a thin root),
same conventions, same multi-cloud anticipation.

## Motivation

Three forces, mirroring the bootstrap module's:

1. **Reuse.** The same hardening applies to any new AWS account we
   bootstrap. Re-deriving it each time is waste.
2. **Open-source contribution.** A focused security-baseline module is
   a better contribution than a fork of someone else's framework.
3. **Multi-cloud anticipation.** GCP and Azure have analogous concerns
   (audit logs, asset inventory, threat detection, alert routing,
   privileged-access role). Sibling repos `terraform-gcp-security-baseline`
   and `terraform-azure-security-baseline` will copy this layout.

Plus, two AWS-specific reasons:

4. **Bootstrap stays re-runnable.** Account hardening shouldn't move
   when bootstrap changes.
5. **AWS service evolution.** Security Hub standards rev (CIS 1.4 →
   3.0), GuardDuty adds detector types, Access Analyzer gains
   modes — better contained in a module that can iterate
   independently.

## Decisions

### D1 — Six sub-modules, one root

```
terraform-aws-security-baseline/
├── main.tf            root composes the six
├── modules/
│   ├── account-hardening/   password policy, S3 account public-access
│   │                         block, EBS default encryption + CMK,
│   │                         (optional) IAM account alias adoption
│   ├── audit-logging/       multi-region CloudTrail + log bucket +
│   │                         KMS log key + log-file validation
│   ├── aws-config/          Config recorder + delivery channel +
│   │                         delivery bucket
│   ├── threat-detection/    GuardDuty detector + Security Hub +
│   │                         standards subscriptions + Access Analyzer
│   ├── alerts/              SNS topic + email subscription +
│   │                         EventBridge rules for high-severity
│   │                         GuardDuty / Security Hub / root login
│   └── operator-role/       InfraAdmin role with MFA-required trust
│                             policy + region-restriction inline policy
└── examples/minimal/
```

Callers can use the root for the full baseline or pull sub-modules
à la carte (e.g. `audit-logging` + `alerts` only, for accounts that
don't yet justify GuardDuty cost).

### D2 — Out of scope

The following are valuable but explicitly NOT part of this module:

- **State backend**, **GitHub OIDC**, **automation role** — all in
  `terraform-aws-bootstrap`.
- **Workload-specific resources** — KMS signing keys, artifact
  buckets, EKS clusters, etc. Each gets its own stack under
  `infra/src/<name>/`.
- **AWS Organizations / multi-account setup** — single-account
  focus. If we ever go multi-account, that's a separate `terraform-aws-organization`
  module orchestrating member accounts.
- **IAM Identity Center (SSO)** — future spec; for now the operator
  role is assumable from the account root via MFA.
- **WAF / Shield Advanced / Inspector v2** — workload-adjacent;
  belongs to a stack that owns the resources being protected.
- **Macie / Detective** — opt-in services with non-trivial cost;
  add later if data classification / forensic timeline becomes a
  requirement.

### D3 — Upstream building blocks

Use `terraform-aws-modules/*` where they handle real complexity.
Hand-roll where they're either thin wrappers around one resource or
where their conventions get in the way:

| Sub-module | Built on | Why / why not |
|---|---|---|
| account-hardening | hand-roll | Trivial primitives (one resource each); upstream wraps would be more LOC, not less. |
| audit-logging | `terraform-aws-modules/cloudtrail/aws` + hand-rolled bucket | The CloudTrail module handles the bucket policy edge cases (service principal access, log-file-validation requirements); we keep direct control of the bucket via `s3-bucket` so we can apply the same `prevent_destroy` + bucket-policy guardrails as the state bucket. |
| aws-config | `terraform-aws-modules/config/aws` | Recorder + delivery channel + bucket policy is fiddly to get right; the upstream nails it. |
| threat-detection | hand-roll | `aws_guardduty_detector`, `aws_securityhub_account`, `aws_securityhub_standards_subscription`, `aws_accessanalyzer_analyzer` — one resource each, no benefit from wrapping. |
| alerts | hand-roll | SNS + EventBridge rules + topic policy. Small surface, full control matters for the routing logic. |
| operator-role | `terraform-aws-modules/iam//modules/iam-assumable-role` | Trust policy with MFA condition is exactly what that sub-module does. |

We do **not** use Cloud Posse account-baseline, Gruntwork Reference
Architecture, or AWS Control Tower for the same reasons documented
in the bootstrap spec D3 (multi-account framework / heavy / labels
convention).

### D4 — Account alias

The account alias is currently set manually as an aws-nuke
prerequisite. `account-hardening` sub-module takes it over via an
`import` block when `manage_account_alias = true` (default
**false** — opt-in to avoid stomping on accounts that have set it
some other way).

When opted in, the module uses `aws_iam_account_alias` with an
`import` block targeting the existing alias value. Subsequent
applies are no-ops; the alias is now tofu-managed.

### D5 — Region restriction

The `operator-role` sub-module attaches an inline IAM policy that
denies any action where `aws:RequestedRegion` is not in
`var.allowed_regions`. **Default: `[var.region]`** — i.e. the
primary region only. Configurable: callers can pass a wider list
to allow multi-region work, or an empty list to disable the
restriction entirely.

Carve-outs for genuinely global services that don't honour
`aws:RequestedRegion`: IAM, CloudFront, Route53, Organizations,
WAFv2 (CloudFront scope), Support, Trusted Advisor.

The same restriction is added to the **bootstrap module's
automation role** in a v0.2 minor on `terraform-aws-bootstrap`
(`var.allowed_regions` on `automation-iam`, same default of
`[var.region]`). See OQ3 below.

### D6 — Audit log retention & encryption

CloudTrail logs and AWS Config history both go to S3 buckets with:

- SSE-KMS using their **own** customer-managed CMKs (separate from
  the state-encryption CMK; least-privilege isolation).
- `prevent_destroy = true` on the buckets.
- Bucket policies that deny non-TLS, deny non-KMS uploads, allow
  the relevant AWS service principal.
- Lifecycle: transition to `STANDARD_IA` at 90 days, `GLACIER_IR`
  at 180 days, expire after 730 days (2 years — balances forensic
  utility against cost).

### D7 — GuardDuty / Security Hub / Access Analyzer scope

- **GuardDuty** — detector in the primary region only by v0.1.
  Multi-region replication is a future minor bump (callers who need
  it can use the sub-module directly with `for_each` over a region
  set).
- **Security Hub** — enable AWS Foundational Security Best Practices
  and CIS AWS Foundations Benchmark v3.0. Skip CIS v1.4 (deprecated)
  and PCI-DSS (workload-specific).
- **Access Analyzer** — single account-level analyzer in the primary
  region, scope `ACCOUNT`. Unused-access analyzer is a future minor
  bump (currently a paid service tier).

### D8 — Alerts routing

One SNS topic, one email subscription. EventBridge rules forward:

- GuardDuty findings of severity HIGH or CRITICAL.
- Security Hub findings of severity HIGH or CRITICAL (deduped via
  `findings.id` to avoid duplicate alerts when GD findings flow into
  SH).
- CloudTrail event `ConsoleLogin` where `userIdentity.type = Root`
  (root login alarm).
- CloudTrail event `*` where `userIdentity.type = Root` AND
  `eventName != ConsoleLogin` (root API usage alarm).

Topic policy grants `events.amazonaws.com` and the local services
publish-to-topic permission.

Per-finding-type topics is a future expansion if signal-to-noise
warrants.

### D9 — Tag propagation, naming, versioning

Same conventions as bootstrap:
- `var.tags` propagated through every taggable resource.
- snake_case Terraform locals; kebab-case AWS `name` attributes.
- Pre-1.0: minor bumps may break input/output surface.
- SHA pin or semver tag for module sources; CKV_TF_1 suppression at
  module call points where pinning to a tag is more readable than a
  SHA.

## Module surface (v0.1 target)

### Required inputs (root)

| Name | Type | Notes |
|---|---|---|
| `account_id` | `string` | 12-digit. |
| `region` | `string` | Primary region for regional resources (CloudTrail, GuardDuty, Access Analyzer, alerts). |
| `project_name` | `string` | Used as resource-name prefix. |
| `alerts_email` | `string` | Subscribed to the SNS alerts topic. |

### Optional inputs (root)

| Name | Type | Default |
|---|---|---|
| `tags` | `map(string)` | `{}` |
| `manage_account_alias` | `bool` | `false` (opt-in; see D4) |
| `allowed_regions` | `list(string)` | `[var.region]` |
| `enable_account_hardening` | `bool` | `true` |
| `enable_audit_logging` | `bool` | `true` |
| `enable_aws_config` | `bool` | `true` |
| `enable_threat_detection` | `bool` | `true` |
| `enable_alerts` | `bool` | `true` |
| `enable_operator_role` | `bool` | `true` |
| `securityhub_standards` | `set(string)` | `["AWS_FSBP", "CIS_v3"]` |
| `audit_log_retention_days` | `number` | `730` |

Each `enable_*` toggle gates a `count = var.enable_X ? 1 : 0` on the
corresponding sub-module call so callers can compose the baseline
à la carte.

### Outputs (root)

| Name | Notes |
|---|---|
| `audit_log_bucket_arn` | CloudTrail bucket ARN. |
| `audit_log_kms_key_arn` | CloudTrail log encryption CMK. |
| `aws_config_bucket_arn` | Config history bucket ARN. |
| `aws_config_kms_key_arn` | Config encryption CMK. |
| `alerts_topic_arn` | SNS topic ARN — for downstream stacks that want to fan out their own alarms to the same topic. |
| `operator_role_arn` | InfraAdmin role ARN. Humans assume this with MFA. |
| `guardduty_detector_id` | For downstream tooling that consumes findings. |

## Open questions

- **OQ1 — Multi-region GuardDuty.** **Resolved (2026-05-06):**
  primary-region-only for v0.1; multi-region is a v0.2 expansion
  if and when it earns its keep.
- **OQ2 — Account alias.** **Resolved (2026-05-06):**
  module default is `manage_account_alias = false` (opt-in) so
  the OSS module is gentle on consumers who already manage it.
  `phpboyscout/infra` itself opts in (`= true`) when calling the
  module.
- **OQ3 — Operator role + bootstrap automation role region
  restriction.** **Resolved (2026-05-06):** region restriction is
  a configurable input on both the operator-role here and on the
  bootstrap automation-iam role (the latter via a v0.2 minor on
  `terraform-aws-bootstrap`). Default in both places is
  `[var.region]` — the primary region only. Callers can widen.
- **OQ4 — Audit log retention default.** **Resolved (2026-05-06):**
  730 days (2 years) as the default; overridable per caller.
- **OQ5 — Inspector v2.** **Resolved (2026-05-06):** workload,
  not account-baseline. Each stack that owns scannable resources
  (EC2 / ECR / Lambda) enables Inspector at the same time. Move
  here later if it ever needs to be account-wide before any
  workload exists.

## Follow-ups

- **`terraform-aws-bootstrap` v0.2** — add `var.allowed_regions` on
  the `automation-iam` sub-module (default `[var.region]`) so the
  CI role's region restriction is symmetric with the operator
  role's (resolution of OQ3). Lands in the bootstrap repo with
  its own spec.
- Sibling spec: `terraform-gcp-security-baseline` v0.1 (separate repo).
- Sibling spec: `terraform-azure-security-baseline` v0.1 (separate repo).
- Spec: IAM Identity Center / SSO module — replaces the
  account-root-MFA trust on the operator role with SSO permission
  sets.

## Implementation plan (post-spec-approval)

1. Create `phpboyscout/terraform-aws-security-baseline` repo (public,
   MIT, same scaffolding as `terraform-aws-bootstrap`).
2. Write the six sub-modules + root + `examples/minimal`, one
   sub-module per commit so each is reviewable.
3. Tag `v0.1.0` once `examples/minimal` validates.
4. Wire up `infra/src/security-baseline/` to consume the module
   (referenced by the v0.1.0 tag).
5. Apply via the bootstrap automation role from CI — first
   end-to-end test of the OIDC chain.
6. Once stable, Phase 4 of the bootstrap (retire `tofu-bootstrap`)
   becomes safe to execute.
