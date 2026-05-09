# `alerts`

SNS topic + email subscription + EventBridge rules wiring high-severity
findings (GuardDuty, Security Hub) and root-account activity (sign-in,
API calls) to a single email address.

## What you get

- `aws_sns_topic` — KMS-encrypted with a dedicated customer CMK,
  with a topic policy that allows the EventBridge service principal
  to publish (scoped via `aws:SourceAccount`).
- `aws_sns_topic_subscription` — email subscription (requires manual
  confirmation by the recipient on first apply; AWS sends the link).
- `aws_kms_key` + `aws_kms_alias` — dedicated CMK so the alerts
  topic doesn't share encryption with the audit / config history.
- Four `aws_cloudwatch_event_rule`s, each gated by an `enable_*`
  toggle:
  - `<topic>-guardduty-high` — GuardDuty findings of severity ≥ 7
    (HIGH or CRITICAL).
  - `<topic>-securityhub-high` — Security Hub findings of severity
    HIGH or CRITICAL, **excluding** GuardDuty-sourced findings to
    avoid duplicate alerts when the GuardDuty integration imports
    them into Security Hub.
  - `<topic>-root-login` — root-account console sign-in events.
  - `<topic>-root-api` — root-account API calls excluding console
    sign-in.

Each rule has a target wired to the SNS topic.

## Usage

```hcl
module "alerts" {
  source = "github.com/phpboyscout/terraform-aws-security-baseline//modules/alerts?ref=v0.1.0"

  account_id   = "049815585546"
  alerts_email = "aws@phpboyscout.uk"

  tags = {
    Project    = "phpboyscout"
    ManagedBy  = "opentofu"
    Repository = "phpboyscout/infra"
  }
}
```

After apply, **check the email address for an AWS confirmation
message and click the link.** The subscription stays
`PendingConfirmation` until then; messages aren't delivered.

## Multi-region note for root-account rules

Console sign-in events (`aws.signin` source) and root-user API calls
are emitted in `us-east-1` for AWS partition. Multi-region CloudTrail
copies them to all regions, but EventBridge rules in non-us-east-1
regions don't always fire on console-sign-in events as reliably as
in us-east-1.

For complete coverage, deploy a second copy of this module to
`us-east-1` with only `enable_root_login_rule` and `enable_root_api_rule`
set to `true` (and the GuardDuty / Security Hub flags `false`). v0.2
of this module may add a built-in mechanism for this; for now it's a
deliberate caller-side composition.

## Adding more alert sources

Downstream stacks publish their own alarms / events to this topic by
referencing the `topic_arn` output:

```hcl
resource "aws_cloudwatch_metric_alarm" "billing" {
  # ...
  alarm_actions = [module.alerts.topic_arn]
}
```

The topic policy already allows the account principal full control,
so no additional grants needed.

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
| [aws_cloudwatch_event_rule.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.root_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.root_login](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.securityhub](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.guardduty_to_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.root_api_to_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.root_login_to_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.securityhub_to_sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_kms_alias.sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.sns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID. Used in topic policy conditions and rule source-account scoping. | `string` | n/a | yes |
| <a name="input_alerts_email"></a> [alerts\_email](#input\_alerts\_email) | Email address subscribed to the alerts topic. AWS will send a confirmation email on first apply — the subscription is `PendingConfirmation` until clicked. | `string` | n/a | yes |
| <a name="input_enable_guardduty_finding_rule"></a> [enable\_guardduty\_finding\_rule](#input\_enable\_guardduty\_finding\_rule) | Whether to create an EventBridge rule forwarding GuardDuty findings of severity HIGH or CRITICAL (numeric ≥ 7) to the alerts topic. | `bool` | `true` | no |
| <a name="input_enable_root_api_rule"></a> [enable\_root\_api\_rule](#input\_enable\_root\_api\_rule) | Whether to create an EventBridge rule alerting on any non-ConsoleLogin API call made by the root user. Same multi-region caveat as the console-sign-in rule. | `bool` | `true` | no |
| <a name="input_enable_root_login_rule"></a> [enable\_root\_login\_rule](#input\_enable\_root\_login\_rule) | Whether to create an EventBridge rule alerting on root-account console sign-in events. NOTE: console sign-in CloudTrail events originate in us-east-1; this rule only fires on it from regions that receive the multi-region trail copy. For complete coverage, additionally deploy this module to us-east-1 with this flag on. | `bool` | `true` | no |
| <a name="input_enable_securityhub_finding_rule"></a> [enable\_securityhub\_finding\_rule](#input\_enable\_securityhub\_finding\_rule) | Whether to create an EventBridge rule forwarding Security Hub findings of severity HIGH or CRITICAL to the alerts topic. Excludes GuardDuty-sourced findings (deduped — they fire via the GuardDuty rule). | `bool` | `true` | no |
| <a name="input_kms_alias"></a> [kms\_alias](#input\_kms\_alias) | Alias for the SNS-encryption CMK, without the `alias/` prefix. | `string` | `"sns-alerts"` | no |
| <a name="input_kms_deletion_window_in_days"></a> [kms\_deletion\_window\_in\_days](#input\_kms\_deletion\_window\_in\_days) | Days the SNS CMK lingers in PendingDeletion if scheduled for deletion. AWS-allowed range is 7-30. | `number` | `30` | no |
| <a name="input_kms_enable_key_rotation"></a> [kms\_enable\_key\_rotation](#input\_kms\_enable\_key\_rotation) | Whether AWS automatically rotates the SNS CMK's key material annually. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every taggable resource this module creates. Merged on top of the consuming provider's `default_tags` — module-supplied tags win on key conflict. | `map(string)` | `{}` | no |
| <a name="input_topic_name"></a> [topic\_name](#input\_topic\_name) | Name of the SNS alerts topic. | `string` | `"security-alerts"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kms_alias_name"></a> [kms\_alias\_name](#output\_kms\_alias\_name) | Full alias of the SNS-encryption CMK (with `alias/` prefix). |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the customer-managed CMK encrypting messages on the alerts topic. |
| <a name="output_subscription_pending_confirmation"></a> [subscription\_pending\_confirmation](#output\_subscription\_pending\_confirmation) | Reminder that the email subscription requires manual confirmation by the recipient on first apply. Always true at apply time; AWS confirms out-of-band. |
| <a name="output_topic_arn"></a> [topic\_arn](#output\_topic\_arn) | ARN of the security alerts SNS topic. Downstream stacks fan their own alarms into this topic by attaching their CloudWatch alarms / EventBridge targets to it. |
| <a name="output_topic_name"></a> [topic\_name](#output\_topic\_name) | Name of the alerts topic. |
<!-- END_TF_DOCS -->
