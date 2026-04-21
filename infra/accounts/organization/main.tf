provider "aws" {
  region = "us-east-1"
  allowed_account_ids = ["686519988262"]
  assume_role {
    role_arn = "arn:aws:iam::686519988262:role/github/common_manager"
  }
  default_tags {
    tags = {
      terraform = "accounts"
      repo      = "terramaps/terramaps-infra"
    }
  }
}
