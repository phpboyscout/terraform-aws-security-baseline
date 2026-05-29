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
  source  = "gitlab.com/phpboyscout/security-baseline/aws"
  version = "0.2.0"
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
  source  = "gitlab.com/phpboyscout/security-baseline/aws"
  version = "0.2.0"
  # ...
  manage_account_alias = true
  account_alias        = "phpboyscout"
}
```

See `modules/account-hardening/README.md` for the rationale.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

No providers.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID. Replace the placeholder default before applying. | `string` | `"123456789012"` | no |
| <a name="input_alerts_email"></a> [alerts\_email](#input\_alerts\_email) | Email address subscribed to the alerts SNS topic. Replace before applying — AWS will send a confirmation email to this address. | `string` | `"alerts@example.invalid"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project tag used to derive default resource names. | `string` | `"example"` | no |
| <a name="input_region"></a> [region](#input\_region) | Primary region the example provisions into. | `string` | `"eu-west-2"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_analyzer_arn"></a> [access\_analyzer\_arn](#output\_access\_analyzer\_arn) | ARN of the IAM Access Analyzer. |
| <a name="output_alerts_topic_arn"></a> [alerts\_topic\_arn](#output\_alerts\_topic\_arn) | ARN of the security alerts SNS topic. Downstream stacks fan their own alarms in by attaching CloudWatch alarms or EventBridge targets to this ARN. |
| <a name="output_audit_log_bucket_arn"></a> [audit\_log\_bucket\_arn](#output\_audit\_log\_bucket\_arn) | ARN of the audit log bucket. |
| <a name="output_audit_trail_arn"></a> [audit\_trail\_arn](#output\_audit\_trail\_arn) | ARN of the CloudTrail trail. |
| <a name="output_aws_config_bucket_arn"></a> [aws\_config\_bucket\_arn](#output\_aws\_config\_bucket\_arn) | ARN of the AWS Config history bucket. |
| <a name="output_ebs_default_kms_key_arn"></a> [ebs\_default\_kms\_key\_arn](#output\_ebs\_default\_kms\_key\_arn) | ARN of the customer-managed CMK used as the EBS default-encryption key. |
| <a name="output_guardduty_detector_id"></a> [guardduty\_detector\_id](#output\_guardduty\_detector\_id) | ID of the GuardDuty detector. |
| <a name="output_operator_role_arn"></a> [operator\_role\_arn](#output\_operator\_role\_arn) | ARN of the operator role. Humans assume this with MFA via `aws sts assume-role`. |
<!-- END_TF_DOCS -->