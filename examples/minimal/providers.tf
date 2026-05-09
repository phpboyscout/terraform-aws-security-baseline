provider "aws" {
  region = var.region

  # Belt-and-braces: refuse to plan / apply against any account other
  # than the one declared. Replace `var.account_id` with your real ID
  # before running this example.
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "example-security-baseline"
      Environment = "example"
      ManagedBy   = "opentofu"
      Repository  = "phpboyscout/terraform-aws-security-baseline"
    }
  }
}
