# common_manager role — assumed by github_actions_role to manage org-level infra
# (ECR, OIDC, state bucket, etc.) in this same account.

data "aws_iam_policy_document" "common-manager" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.gh_actions.arn]
    }
    # Should add condition requiring it to be the infra repo too
    # condition {
    #   test     = "StringLike"
    #   variable = "aws:PrincipalTag/Branch"
    #   values = [
    #     "refs/heads/main",
    #   ]
    # }
  }
}

data "aws_iam_policy" "common-manager" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "common-manager" {
  path                = "/github/"
  name                = "common_manager"
  assume_role_policy  = data.aws_iam_policy_document.common-manager.json
  managed_policy_arns = [data.aws_iam_policy.common-manager.arn]
}

# ecr_builder role — assumed by github_actions_role to push images to ECR
# (used by the app's CI build pipeline, not the infra pipeline)

data "aws_iam_policy_document" "gh_builder_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.gh_actions.arn]
    }
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalTag/Branch"
      values = [
        "refs/heads/main",
        "refs/heads/develop",
        "refs/heads/release/*",
        "refs/heads/feature/*",
        "refs/tags/v*",
      ]
    }
  }
}

data "aws_iam_policy_document" "gh_builder_permission" {
  statement {
    sid       = "ECRAdmin"
    actions   = ["ecr:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "gh_builder" {
  path               = "/github/"
  name               = "ecr_builder"
  assume_role_policy = data.aws_iam_policy_document.gh_builder_trust.json
  inline_policy {
    name   = "ECRAdmin"
    policy = data.aws_iam_policy_document.gh_builder_permission.json
  }
}

output "ecr-builder-role" {
  description = "ecr_builder role ARN — use in app CI pipeline to push images"
  value       = aws_iam_role.gh_builder.arn
}
