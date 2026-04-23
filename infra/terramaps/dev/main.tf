locals {
  deployment = "terramaps-${var.stack}"
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

