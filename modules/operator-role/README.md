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
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.region_restriction](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID. Used as the trusted principal in the role's assume-role policy. | `string` | n/a | yes |
| <a name="input_additional_policy_arns"></a> [additional\_policy\_arns](#input\_additional\_policy\_arns) | ARNs of additional managed policies to attach to the role. Useful for layering AWS-managed policies (e.g. ReadOnlyAccess, IAMFullAccess) on top of, or instead of, AdministratorAccess. | `set(string)` | `[]` | no |
| <a name="input_allowed_regions"></a> [allowed\_regions](#input\_allowed\_regions) | Regions in which the operator role can operate. Null defaults to `[var.region]` (single-region restriction). Pass a wider list for multi-region setups, or an empty list `[]` to disable the restriction entirely. | `list(string)` | `null` | no |
| <a name="input_attach_admin_policy"></a> [attach\_admin\_policy](#input\_attach\_admin\_policy) | Whether to attach the AWS-managed `AdministratorAccess` policy. Default true — appropriate for the operator role for a single-tenant account. For tighter setups, set false and pass narrower policies via `additional_policy_arns`. | `bool` | `true` | no |
| <a name="input_globally_scoped_actions"></a> [globally\_scoped\_actions](#input\_globally\_scoped\_actions) | IAM action prefixes for globally-scoped services that don't honour `aws:RequestedRegion` and must therefore be exempted from the region restriction. Default covers the standard global / billing services; extend to add provider-level globals or trim if you want to block specific global APIs. | `list(string)` | <pre>[<br/>  "iam:*",<br/>  "sts:*",<br/>  "cloudfront:*",<br/>  "route53:*",<br/>  "route53domains:*",<br/>  "organizations:*",<br/>  "support:*",<br/>  "trustedadvisor:*",<br/>  "waf:*",<br/>  "wafv2:*",<br/>  "shield:*",<br/>  "globalaccelerator:*",<br/>  "account:*",<br/>  "aws-portal:*",<br/>  "billing:*",<br/>  "ce:*",<br/>  "cur:*",<br/>  "savingsplans:*",<br/>  "tax:*",<br/>  "payments:*",<br/>  "health:*",<br/>  "kms:DescribeKey",<br/>  "kms:ListAliases"<br/>]</pre> | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration, in seconds, when assuming this role. AWS-allowed range 3600-43200. | `number` | `3600` | no |
| <a name="input_mfa_age"></a> [mfa\_age](#input\_mfa\_age) | Maximum age, in seconds, of the MFA verification when assuming the role. Default 14400 (4 hours) balances security against operator friction. | `number` | `14400` | no |
| <a name="input_region"></a> [region](#input\_region) | Primary region. Defaults `allowed_regions` to a single-element list containing this when allowed\_regions is null. | `string` | n/a | yes |
| <a name="input_require_mfa"></a> [require\_mfa](#input\_require\_mfa) | Whether the assume-role trust policy requires `aws:MultiFactorAuthPresent = true`. Strongly recommended for any role granting administrative access. Disable only for break-glass / emergency-only roles where MFA is impossible. | `bool` | `true` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the operator role. | `string` | `"InfraAdmin"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_allowed_regions"></a> [allowed\_regions](#output\_allowed\_regions) | Regions in which this role can operate (region restriction). Empty list means no restriction is in effect. |
| <a name="output_region_restriction_enabled"></a> [region\_restriction\_enabled](#output\_region\_restriction\_enabled) | Whether the region-restriction inline policy is attached. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the operator role. Humans assume this with MFA via `aws sts assume-role` (or, more commonly, an SSO-style helper). |
| <a name="output_role_id"></a> [role\_id](#output\_role\_id) | Unique identifier of the operator role (e.g. for use in trust conditions on resources granted to this role). |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the operator role. |
<!-- END_TF_DOCS -->
