# terraform-aws-security-baseline

**Opinionated AWS security baseline for OpenTofu and Terraform.** Hardens an
account after bootstrap: account-level hygiene, audit logging, threat detection
and the alerting to make any of it useful. Pre-1.0, so pin to a tag rather than
a branch.

> **This is a read-only mirror. The canonical repository is on GitLab:**
> **https://gitlab.com/phpboyscout/iac/terraform-aws-security-baseline**
>
> Issues and merge requests are handled there.

## Using it

The module is published to GitLab's Terraform module registry, so consume it
from there rather than from a git source:

```hcl
module "security_baseline" {
  source  = "gitlab.com/phpboyscout/security-baseline/aws"
  version = "0.2.0"
}
```

## Documentation

Full documentation: **https://aws-security-baseline.iac.phpboyscout.uk**

The reasoning behind it is written up in
[Infrastructure with AWS and OpenTofu](https://phpboyscout.uk/topics/infrastructure/).
