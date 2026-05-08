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
  region       = "eu-west-2"
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
<!-- terraform-docs auto-injects the inputs/outputs/requirements
     tables here on `just docs`. -->
<!-- END_TF_DOCS -->
