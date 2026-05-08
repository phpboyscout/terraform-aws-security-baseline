---
title: terraform-aws-security-baseline
description: Opinionated AWS security baseline for OpenTofu — six sub-modules, no framework.
date: 2026-05-06
tags: [overview, introduction]
authors: [Matt Cockayne <matt@phpboyscout.com>]
hide:
  - navigation
---

# terraform-aws-security-baseline

A reusable OpenTofu/Terraform module that hardens an AWS account
*post-bootstrap*. Sibling to
[`terraform-aws-bootstrap`][bootstrap]: that module produces the bare
minimum needed for the next `tofu apply` (state backend, GitHub OIDC,
automation role); this one runs second and brings the account up to
"ready for workloads".

Six sub-modules, no framework, no labels conventions:

- **`account-hardening`** — password policy, S3 public-access block,
  EBS default encryption + CMK, optional alias adoption.
- **`audit-logging`** — multi-region CloudTrail + KMS-encrypted log
  bucket.
- **`aws-config`** — Config recorder + delivery channel + history
  bucket.
- **`threat-detection`** — GuardDuty + Security Hub + Access Analyzer.
- **`alerts`** — SNS topic + EventBridge rules for HIGH/CRITICAL
  findings + root-account alarms.
- **`operator-role`** — `InfraAdmin` with MFA-required trust + a
  configurable region-restriction policy.

Each sub-module is gated by a corresponding `enable_*` toggle so
callers can compose à la carte.

## Start here

- **[Quick start](https://github.com/phpboyscout/terraform-aws-security-baseline#quick-start)** —
  one-call usage in the README.
- **[Master spec](development/specs/2026-05-06-security-baseline-v0.1.md)** —
  scope decisions, sub-module breakdown, rejected alternatives,
  open-question resolutions, multi-cloud roadmap.
- **[Engineering standards](development/engineering-standards.md)** —
  module conventions, the tag-propagation rule, naming, security
  defaults.

## Related projects

- **[`phpboyscout/terraform-aws-bootstrap`][bootstrap]** — the
  pre-baseline module.
- **[`phpboyscout/infra`](https://github.com/phpboyscout/infra)** —
  the first user of both modules; private, defines the AWS account
  that supports `go-tool-base` and `rust-tool-base`.

[bootstrap]: https://github.com/phpboyscout/terraform-aws-bootstrap
