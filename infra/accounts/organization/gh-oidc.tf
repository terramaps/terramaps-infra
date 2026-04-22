/*
Sets up the GitHub OIDC provider and a shared middleman IAM role that all
GitHub Actions workflows in the terramaps repo authenticate through.

Auth flow:
  1. GH workflow assumes the OIDC role (directly trusted via the OIDC provider)
  2. OIDC role assumes github_actions_role (the middleman, in this same account)
  3. github_actions_role assumes the per-environment deploy_role or domain_manager role

See: https://github.com/aws-actions/configure-aws-credentials#session-tagging
*/

data "aws_iam_policy_document" "github_oidc_policy" {
  version = "2012-10-17"
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    effect    = "Allow"
    resources = [aws_iam_role.gh_actions.arn]
  }
}

resource "aws_iam_policy" "github_oidc_policy" {
  name        = "github_oidc_policy"
  path        = "/github/"
  description = "Allows the GH OIDC role to assume the middleman role and tag sessions."
  policy      = data.aws_iam_policy_document.github_oidc_policy.json
}

module "github-oidc-provider" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "2.2.0"

  # Set to false if an OIDC provider already exists in this account
  create_oidc_provider      = true
  oidc_role_attach_policies = [aws_iam_policy.github_oidc_policy.arn]

  repositories = [
    "terramaps/*"
  ]
}

data "aws_iam_policy_document" "gh_actions_trust" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::686519988262:root"]
    }
  }
}

data "aws_iam_policy_document" "gh_actions_permissions" {
  statement {
    sid    = "AllowAssumeGithubRoles"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    resources = ["arn:aws:iam::*:role/github/*"]
  }
}

resource "aws_iam_policy" "gh_actions_permissions" {
  name   = "AllowAssumeGithubRoles"
  policy = data.aws_iam_policy_document.gh_actions_permissions.json
}

resource "aws_iam_role" "gh_actions" {
  name               = "github_actions_role"
  path               = "/github/"
  assume_role_policy = data.aws_iam_policy_document.gh_actions_trust.json
  managed_policy_arns = [
    aws_iam_policy.gh_actions_permissions.arn,
    aws_iam_policy.terraform_state.arn,
  ]
}

output "gh_oidc_role" {
  description = "OIDC entrypoint role ARN — use in iam-auth/action.yml step 1"
  value       = module.github-oidc-provider.oidc_role
}

output "gh_oidc_middleman" {
  description = "Middleman role ARN — use in iam-auth/action.yml step 2"
  value       = aws_iam_role.gh_actions.arn
}
