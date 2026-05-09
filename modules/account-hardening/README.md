# `account-hardening`

Account-level hygiene primitives:

- IAM account **password policy** (sensible production defaults; per-field overridable)
- S3 **account-wide public-access block** (all four settings on)
- EBS **default encryption** with a customer-managed CMK
- (optional) IAM **account alias** adoption

The first three are always created; the alias is opt-in
(`manage_account_alias = true`) because callers may already manage it
elsewhere — Control Tower, OrgFormation, manual setup as an aws-nuke
prerequisite.

## What you get by default

| Resource | Default |
|---|---|
| `aws_iam_account_password_policy` | 14-char minimum; lowercase + uppercase + digits + symbols required; 90-day max age; 24-password reuse prevention |
| `aws_s3_account_public_access_block` | All four block / ignore / restrict settings enabled |
| `aws_kms_key` (EBS default) | Customer-managed; rotation on; 30-day deletion window; account-root-only policy |
| `aws_kms_alias` | `alias/ebs-default` |
| `aws_ebs_default_kms_key` + `aws_ebs_encryption_by_default` | Pointing at the CMK; encryption-by-default enabled |

## Usage

```hcl
module "account_hardening" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline//modules/account-hardening?ref=v0.1.0"

  account_id = "049815585546"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }

  # Take over the IAM account alias (existing value must match).
  # If an alias already exists in the account, your *root* module
  # also needs an `import` block — see "Account alias adoption"
  # below. Without it, the first apply fails with EntityAlreadyExists.
  manage_account_alias = true
  account_alias        = "phpboyscout"
}
```

## EBS default key — service principals and grants

The CMK's policy grants only the account root. Direct EC2 launches via
console / CLI / IaC use the caller's identity, which works for any
admin or any role that has `kms:*` (or the relevant Encrypt /
GenerateDataKey actions). AWS-managed services that need to use the
CMK on your behalf — typically the Auto Scaling service-linked role
(`AWSServiceRoleForAutoScaling`) for ASG-launched instances, RDS for
encrypted RDS volumes — need additional access via either:

- A `kms:CreateGrant` grant on the CMK (preferred — narrow, dynamic,
  scoped per resource), or
- Additional statements on the key policy (broader, static).

This module deliberately leaves those out so workload-side stacks can
attach exactly what they need:

```hcl
resource "aws_kms_grant" "asg_use_ebs_default" {
  name              = "asg-use-ebs-default"
  key_id            = module.account_hardening.ebs_default_kms_key_id
  grantee_principal = "arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
  operations        = ["Encrypt", "Decrypt", "ReEncryptFrom", "ReEncryptTo", "GenerateDataKey", "GenerateDataKeyWithoutPlaintext", "DescribeKey", "CreateGrant"]
}
```

## Account alias adoption

When `manage_account_alias = true`, this module declares the
`aws_iam_account_alias` resource. If an alias already exists on the
account (e.g. set manually as an aws-nuke prerequisite), the create
will collide and the apply will fail unless you've imported it first.

OpenTofu only allows `import` blocks in the **root** module, so this
sub-module deliberately doesn't declare one — it would silently fail
to compose the moment you consume the module via `module "..." { ... }`.
Adopting an existing alias is therefore a caller-side concern: drop an
`import` block in your own root, addressing the resource through the
module:

```hcl
import {
  to = module.account_hardening.aws_iam_account_alias.this[0]
  id = "phpboyscout"
}

module "account_hardening" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline//modules/account-hardening?ref=v0.1.0"
  # ...
  manage_account_alias = true
  account_alias        = "phpboyscout"
}
```

If you're calling the **root** `terraform-aws-security-baseline` module
(not the sub-module directly), the address adds another hop:

```hcl
import {
  to = module.security_baseline.module.account_hardening[0].aws_iam_account_alias.this[0]
  id = "phpboyscout"
}
```

Set the alias manually first if it doesn't already exist:

```sh
aws iam create-account-alias --account-alias <alias>
```

After the first successful apply, the import is satisfied and can be
left in place (idempotent) or removed.

To stop managing the alias, set `manage_account_alias = false` — the
next apply removes the resource from state but does **not** delete the
alias from AWS (the resource has no destroy semantics that would; the
alias persists).

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
| [aws_ebs_default_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_default_kms_key) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_iam_account_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_alias) | resource |
| [aws_iam_account_password_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |
| [aws_kms_alias.ebs_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.ebs_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_alias"></a> [account\_alias](#input\_account\_alias) | The IAM account alias value to import and manage. Required when `manage_account_alias = true`; ignored otherwise. The alias must already exist in AWS — set it manually with `aws iam create-account-alias` before applying. | `string` | `null` | no |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID. Used as the root principal in the EBS default-encryption KMS key policy. | `string` | n/a | yes |
| <a name="input_ebs_kms_alias"></a> [ebs\_kms\_alias](#input\_ebs\_kms\_alias) | Alias for the EBS default-encryption CMK, without the `alias/` prefix. | `string` | `"ebs-default"` | no |
| <a name="input_ebs_kms_deletion_window_in_days"></a> [ebs\_kms\_deletion\_window\_in\_days](#input\_ebs\_kms\_deletion\_window\_in\_days) | Days the EBS default-encryption CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30. | `number` | `30` | no |
| <a name="input_ebs_kms_enable_key_rotation"></a> [ebs\_kms\_enable\_key\_rotation](#input\_ebs\_kms\_enable\_key\_rotation) | Whether AWS automatically rotates the EBS default-encryption CMK's key material annually. | `bool` | `true` | no |
| <a name="input_manage_account_alias"></a> [manage\_account\_alias](#input\_manage\_account\_alias) | Whether this module manages the IAM account alias. The default — false — leaves the alias as-is (set externally; e.g. as an aws-nuke prerequisite). Set true to take it over via an `import` block; in that case `account_alias` must be the existing alias value. | `bool` | `false` | no |
| <a name="input_password_policy"></a> [password\_policy](#input\_password\_policy) | IAM account password policy. Defaults are sensible for any production workload; override per-field as needed. | <pre>object({<br/>    minimum_password_length        = optional(number, 14)<br/>    require_lowercase_characters   = optional(bool, true)<br/>    require_uppercase_characters   = optional(bool, true)<br/>    require_numbers                = optional(bool, true)<br/>    require_symbols                = optional(bool, true)<br/>    allow_users_to_change_password = optional(bool, true)<br/>    hard_expiry                    = optional(bool, false)<br/>    max_password_age               = optional(number, 90)<br/>    password_reuse_prevention      = optional(number, 24)<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_alias"></a> [account\_alias](#output\_account\_alias) | IAM account alias managed by this module. Null when `manage_account_alias = false`. |
| <a name="output_ebs_default_kms_alias_name"></a> [ebs\_default\_kms\_alias\_name](#output\_ebs\_default\_kms\_alias\_name) | Full alias of the EBS default-encryption CMK (with `alias/` prefix). |
| <a name="output_ebs_default_kms_key_arn"></a> [ebs\_default\_kms\_key\_arn](#output\_ebs\_default\_kms\_key\_arn) | ARN of the customer-managed CMK used as the EBS default-encryption key. |
| <a name="output_ebs_default_kms_key_id"></a> [ebs\_default\_kms\_key\_id](#output\_ebs\_default\_kms\_key\_id) | Key ID of the EBS default-encryption CMK. |
| <a name="output_password_policy_min_length"></a> [password\_policy\_min\_length](#output\_password\_policy\_min\_length) | Minimum password length the IAM account password policy enforces. Useful for downstream documentation / Security Hub findings reconciliation. |
<!-- END_TF_DOCS -->
