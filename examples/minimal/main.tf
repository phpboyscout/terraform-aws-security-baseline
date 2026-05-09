# Minimal caller of terraform-aws-security-baseline. The four required
# inputs plus a `tags` map; every sub-module enabled at its default
# settings.
#
# `source = "../../"` references the root module directly so this
# example can be validated in CI without resolving the GitHub source.
# Real callers would write:
#
#   source = "github.com/phpboyscout/terraform-aws-security-baseline?ref=v0.1.0"

module "security_baseline" {
  source = "../../"

  account_id   = var.account_id
  region       = var.region
  project_name = var.project_name
  alerts_email = var.alerts_email

  tags = {
    Stack = "security-baseline-example"
  }
}
