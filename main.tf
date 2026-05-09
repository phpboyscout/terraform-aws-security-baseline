# ----------------------------------------------------------------------
# Root composition — calls each sub-module gated by its `enable_*`
# toggle. var.tags propagated to all six. Naming defaults derive from
# project_name + account_id; override individual *_name inputs to
# break the convention.
# ----------------------------------------------------------------------

locals {
  log_bucket_name    = coalesce(var.log_bucket_name, "${var.project_name}-audit-logs-${var.account_id}")
  config_bucket_name = coalesce(var.config_bucket_name, "${var.project_name}-config-${var.account_id}")
}

module "account_hardening" {
  count  = var.enable_account_hardening ? 1 : 0
  source = "./modules/account-hardening"

  account_id           = var.account_id
  manage_account_alias = var.manage_account_alias
  account_alias        = var.account_alias

  tags = var.tags
}

module "audit_logging" {
  count  = var.enable_audit_logging ? 1 : 0
  source = "./modules/audit-logging"

  account_id         = var.account_id
  region             = var.region
  log_bucket_name    = local.log_bucket_name
  log_retention_days = var.audit_retention_days

  tags = var.tags
}

module "aws_config" {
  count  = var.enable_aws_config ? 1 : 0
  source = "./modules/aws-config"

  account_id             = var.account_id
  config_bucket_name     = local.config_bucket_name
  history_retention_days = var.audit_retention_days

  tags = var.tags
}

module "threat_detection" {
  count  = var.enable_threat_detection ? 1 : 0
  source = "./modules/threat-detection"

  region                = var.region
  securityhub_standards = var.securityhub_standards

  tags = var.tags
}

module "alerts" {
  count  = var.enable_alerts ? 1 : 0
  source = "./modules/alerts"

  account_id   = var.account_id
  alerts_email = var.alerts_email

  tags = var.tags
}

module "operator_role" {
  count  = var.enable_operator_role ? 1 : 0
  source = "./modules/operator-role"

  account_id      = var.account_id
  region          = var.region
  role_name       = var.operator_role_name
  allowed_regions = var.allowed_regions

  tags = var.tags
}
