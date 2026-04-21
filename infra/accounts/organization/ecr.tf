# ECR repositories — all docker images for terramaps live here in the org account.
# The dev and prod deployment accounts are granted pull access.

resource "aws_ecr_repository" "ecr" {
  for_each             = toset(local.ecr_repos)
  name                 = each.key
  image_tag_mutability = "IMMUTABLE" 
  lifecycle {
    prevent_destroy = true
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_policy_document" "ecr" {
  statement {
    sid    = "AllowPull"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = toset([for id in local.aws_workspaces : "arn:aws:iam::${id}:root"])
    }
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:ListTagsForResource",
      "ecr:DescribeImageScanFindings"
    ]
  }
}

resource "aws_ecr_repository_policy" "ecr" {
  for_each   = toset(local.ecr_repos)
  repository = each.key
  policy     = data.aws_iam_policy_document.ecr.json
  depends_on = [aws_ecr_repository.ecr]
}
