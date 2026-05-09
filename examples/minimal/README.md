# Minimal example

Smallest possible caller of `terraform-aws-security-baseline`. Used as
both a reference for what consumer code looks like and as a CI smoke
test (validated by every PR).

Placeholder defaults let `tofu validate` succeed without inputs. To
actually `tofu apply` against your own account, override the four
inputs:

```sh
tofu init
tofu plan \
  -var 'account_id=049815585546' \
  -var 'region=eu-west-2' \
  -var 'project_name=phpboyscout' \
  -var 'alerts_email=aws@phpboyscout.uk'
```

…or drop a `terraform.tfvars` next to `main.tf` (gitignored anyway
for non-`*.secret.tfvars` files unless you commit it intentionally).

## What this example provisions

When applied with all defaults, the six sub-modules together produce:

- **account-hardening** — IAM password policy, S3 account-wide
  public-access block, EBS default encryption + customer CMK.
- **audit-logging** — multi-region CloudTrail with log-file
  validation; KMS-encrypted log bucket
  (`<project_name>-audit-logs-<account_id>`).
- **aws-config** — Config recorder + delivery channel + KMS-encrypted
  history bucket (`<project_name>-config-<account_id>`).
- **threat-detection** — GuardDuty detector, Security Hub with
  FSBP + CIS v3.0, IAM Access Analyzer.
- **alerts** — SNS topic + email subscription + EventBridge rules
  forwarding HIGH/CRITICAL GuardDuty + Security Hub findings and
  root-account login / API activity.
- **operator-role** — `InfraAdmin` role with MFA-required trust and a
  region-restriction policy pinned to `var.region`.

## Real-world callers

For real callers (anywhere outside this repo), change the module
source:

```hcl
module "security_baseline" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline?ref=v0.1.0"
  # ...
}
```

Pin to a tag, never to a branch.

## Adopting an existing IAM account alias

If your account already has an alias set (e.g. as an aws-nuke
prerequisite) and you want this module to manage it, add an `import`
block in your root and set `manage_account_alias = true`:

```hcl
import {
  to = module.security_baseline.module.account_hardening[0].aws_iam_account_alias.this[0]
  id = "phpboyscout"
}

module "security_baseline" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline?ref=v0.1.0"
  # ...
  manage_account_alias = true
  account_alias        = "phpboyscout"
}
```

See `modules/account-hardening/README.md` for the rationale.
