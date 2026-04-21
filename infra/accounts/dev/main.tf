terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.85.0"
    }
  }
  required_version = "~> 1.2"
  backend "s3" {
    # State stored in the organization account's bucket
    bucket         = "terramaps-infrastructure"
    key            = "terraform/accounts/dev.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["336519019521"]
  assume_role {
    role_arn = "arn:aws:iam::336519019521:role/github/deploy_role"
  }
  default_tags {
    tags = {
      terraform = "accounts"
      stack     = "dev"
      repo      = "terramaps/terramaps-app"
    }
  }
}

# deploy_role — assumed by github_actions_role (in the org account) to deploy
# all terramaps infrastructure into this dev account.
data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::686519988262:role/github/github_actions_role"]
    }
  }
}

data "aws_iam_policy" "this" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "this" {
  path                = "/github/"
  name                = "deploy_role"
  assume_role_policy  = data.aws_iam_policy_document.this.json
  managed_policy_arns = [data.aws_iam_policy.this.arn]
}

output "role_arn" {
  description = "deploy_role ARN — use as aws-provider.assume-role in dev.auto.tfvars"
  value       = aws_iam_role.this.arn
}
