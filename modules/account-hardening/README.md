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

  # Take over the IAM account alias (existing value must match):
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

When `manage_account_alias = true`, the module's `import` block adopts
the existing alias on first apply. **The alias must already exist in
AWS** — if it doesn't, the import errors. Set it manually first:

```sh
aws iam create-account-alias --account-alias <alias>
```

Subsequent applies are no-ops unless the value changes. To stop
managing the alias, set `manage_account_alias = false` — `tofu apply`
will remove the resource from state but **not** delete the alias from
AWS (no destroy implied; the alias persists).

<!-- BEGIN_TF_DOCS -->
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->
