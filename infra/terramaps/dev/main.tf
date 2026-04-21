locals {
  deployment  = "terramaps-${var.stack}"
  domain_name = "${var.subdomains.app}.terramaps.us"
  api_domain_name = (
    var.subdomains.api != null && var.subdomains.api != ""
    ? "${var.subdomains.api}.terramaps.us"
    : "api-${var.subdomains.app}.terramaps.us"
  ) # either {subdomain.api}.terramaps.us or api-{subdomain.app}.terramaps.us
}

provider "aws" {
  region              = var.aws-region
  allowed_account_ids = [var.aws-provider.id]
  assume_role {
    role_arn = var.aws-provider.assume-role
  }

  default_tags {
    tags = {
      Environment = var.stack
      Application = "terramaps"
    }
  }
}

