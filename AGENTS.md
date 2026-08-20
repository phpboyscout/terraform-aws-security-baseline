# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, agy, codex, etc.) when working with code in this repository.

## Project shape

`phpboyscout/terraform-aws-security-baseline` is a **reusable
OpenTofu/Terraform module** that hardens an AWS account *post-bootstrap*.
Sibling to [`terraform-aws-bootstrap`](https://gitlab.com/phpboyscout/terraform-aws-bootstrap):
that module produces the bare minimum needed for the next `tofu apply`
(state backend, OIDC — GitHub or GitLab, selectable — automation
role); this one runs second and brings the account up to "ready for
workloads".

Six sub-modules behind a thin root:

| Sub-module | Produces |
|---|---|
| `modules/account-hardening/` | password policy, S3 public-access block, EBS default encryption + CMK, optional alias adoption |
| `modules/audit-logging/` | multi-region CloudTrail + KMS-encrypted log bucket |
| `modules/aws-config/` | Config recorder + delivery channel + history bucket |
| `modules/threat-detection/` | GuardDuty + Security Hub (FSBP + CIS v3.0) + Access Analyzer |
| `modules/alerts/` | SNS topic + email subscription + EventBridge rules |
| `modules/operator-role/` | InfraAdmin role with MFA-required trust + region-restriction policy |

Each sub-module is gated by a corresponding `enable_*` toggle on the
root so callers can compose à la carte.

**Out of scope** (and why): bootstrap concerns (state backend, OIDC,
automation role) live in `terraform-aws-bootstrap`. Workload-specific
resources, multi-account Organizations, IAM Identity Center / SSO,
Inspector v2, Macie, Detective, WAF, Shield Advanced — all out per the
master spec.

## Tagging — non-negotiable convention

**Every taggable resource accepts and propagates `var.tags`.** Two-layer
pattern:

1. **Provider-level `default_tags`** — set by the *caller's* provider
   block. Cross-cutting tags (`Project`, `ManagedBy`, `Repository`) live
   here.
2. **Module-level `var.tags`** — every module exposes this and threads
   it through every taggable resource using `merge(var.tags, { … })`
   for any per-resource additions. Module-supplied tags win on key
   conflict over provider `default_tags`.

When adding a new taggable resource: it MUST take `tags = merge(var.tags,
{ Component = "<sub-module>" })` and the module's `variables.tf` MUST
expose a `tags` input. No exceptions.

Standard tag set documented in `docs/development/engineering-standards.md`.

## Spec-first discipline

**No HCL lands without a spec it implements.** Specs live in
`docs/development/specs/<YYYY-MM-DD>-<slug>.md` (Zensical-rendered with
status pills). PRs cite the spec they implement; status flows
`draft → approved → implemented`.

Master spec: `2026-05-06-security-baseline-v0.1.md`.

## Tooling

Same toolchain as the bootstrap module:

- **OpenTofu version** pinned in `.opentofu-version` (currently
  `1.11.6`). Locally managed via `mise → tenv → tofu`; the mise shim
  dir is `~/.local/share/mise/shims`. In non-interactive shells,
  prepend it.
- **Task runner:** `justfile`.
- **Pre-commit hooks** mirror the CI gate.
- **CI** lives in `.gitlab-ci.yml`, consuming components from
  `phpboyscout/cicd` (lint / security / validate / `zensical-pages`
  for the docs site).

## Branch and commit workflow

`terraform-aws-security-baseline` is **trunk-based**: branch from
`main`, MR to `main`. There is no `develop` branch.

- Releases are cut by **`releaser-pleaser`** — it maintains a Release
  MR on `main`; merging that MR publishes a `vX.Y.Z` tag whose
  pipeline runs `tofu-module-publish` against the GitLab Module
  Registry. Merging the Release MR is the human gate for a publish.
- Branch protection is **active** on `main` — managed in the GitLab
  project UI.
- `RELEASER_PLEASER_TOKEN` (group-level CI variable) must be a PAT
  with `api` + `write_repository` — **not** `CI_JOB_TOKEN`, which
  can't open MRs.

### Commit Conventions

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/).

**Do not commit without explicit user approval.** Present a summary of
changes and a proposed message, then wait for confirmation.

**Do not add AI attribution** — no `Co-Authored-By:` trailers naming an
AI, no references to AI assistance in commit messages. The committing
developer owns the change entirely.

| Type | Release |
|------|---------|
| `feat(scope):` | Minor |
| `fix(scope):` / `perf(scope):` / `refactor(scope):` | Patch |
| `ci:` / `chore:` / `style:` / `docs:` / `test:` | None |
| `BREAKING CHANGE:` footer | Major |

**Scope is the sub-module short name** — `feat(account-hardening):`,
`fix(audit-logging):`, `feat(operator-role):`, `chore(alerts):`. For
repo-wide changes use `module`. For CI/workflows use `ci`. Each
commit represents one coherent change.

## Where to look for things that aren't obvious

- **Tagging convention:** `docs/development/engineering-standards.md §1`.
- **Module input/output discipline:** `docs/development/engineering-standards.md §3`
  — every variable typed and documented; every output documented;
  sensitive values explicitly flagged.
- **Naming:** snake_case Terraform locals, kebab-case AWS resource
  names (consumer-overridable via inputs).
- **Why six sub-modules and not one:** master spec
  `docs/development/specs/2026-05-06-security-baseline-v0.1.md`.
- **Open-question resolutions:** master spec, "Open questions" section.
  All five resolved before the spec was approved.
