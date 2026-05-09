# `operator-role`

Human operator role (`InfraAdmin` by default) with an MFA-required
trust policy and a region-restriction inline policy. Designed for
single-tenant accounts where humans assume one role to do anything
administrative; for multi-account or SSO-driven setups, see the
"Multi-account / SSO" note below.

## What you get

- `aws_iam_role` — trust policy allows `arn:aws:iam::<account>:root`
  (i.e. anyone in the account with permission to call `sts:AssumeRole`)
  to assume, gated by `aws:MultiFactorAuthPresent = true` and
  `aws:MultiFactorAuthAge < 14400` (4 hours).
- `aws_iam_role_policy_attachment` to AWS-managed
  `AdministratorAccess` (toggle off with `attach_admin_policy = false`
  if you'd rather attach narrower policies).
- `aws_iam_role_policy` (inline) — region restriction. Deny all
  actions outside `var.allowed_regions` (default `[var.region]`),
  with `NotAction` carve-outs for globally-scoped services.

## Usage

```hcl
module "operator_role" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline//modules/operator-role?ref=v0.1.0"

  account_id = "049815585546"
  region     = "eu-west-2"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

A human operator with credentials for an IAM user in this account then
assumes the role with MFA:

```sh
aws sts assume-role \
  --role-arn "$(tofu output -raw operator_role_arn)" \
  --role-session-name matt \
  --serial-number arn:aws:iam::049815585546:mfa/matt \
  --token-code 123456
```

## Region restriction

Default: `allowed_regions = [var.region]` — the role can only operate
in the primary region. Globally-scoped services (IAM, CloudFront,
Route53, billing APIs, etc.) are exempted from the restriction via
`NotAction` on the deny statement; see `var.globally_scoped_actions`
for the full list.

To allow multi-region operation:

```hcl
module "operator_role" {
  # ...
  allowed_regions = ["eu-west-2", "eu-west-1", "us-east-1"]
}
```

To disable the restriction entirely (e.g. for a break-glass role
that needs to act anywhere):

```hcl
module "operator_role" {
  # ...
  allowed_regions = []
}
```

## Multi-account / SSO note

In v0.1, this module assumes a single-account setup with humans
authenticating via an IAM user in the same account. For multi-account
or SSO-driven setups, the trust principal would change:

- **AWS Organizations + Identity Center (SSO):** SSO permission sets
  generate per-account roles managed by Identity Center; this module
  isn't the right tool. Disable it (`enable_operator_role = false`
  on the security-baseline root) and let SSO own the role lifecycle.
- **Cross-account assume:** trust the *origin* account's IAM user / role
  ARN instead of the local account root. Override the trust policy by
  using this sub-module's source as a starting point and forking the
  trust statement, or extend this module to accept a `trusted_principals`
  list (a v0.2 candidate).

## What's deliberately not here

- **Source-IP restrictions** in the trust policy — VPNs / dynamic IPs
  make these brittle. v0.2 candidate if a strong use case appears.
- **Permissions boundary** on the role — out of scope for v0.1; layered
  setups can attach one externally with `aws_iam_role` `permissions_boundary`
  (the upstream resource accepts it but this module's role doesn't yet
  expose it as an input).

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->
