# S3 bucket for all Terraform remote state.
# IMPORTANT: apply this with a local backend first, then migrate.
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terramaps-infrastructure"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid       = "DynamoDBLockFullAccess"
    effect    = "Allow"
    resources = [aws_dynamodb_table.terraform_locks.arn]
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
  }
  statement {
    sid       = "ListTerraformInfraBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
  }
  statement {
    sid       = "FullAccessTerraformStateFiles"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/terraform/*"]
  }
}

resource "aws_iam_policy" "terraform_state" {
  name        = "TerraformStateFullAccess"
  policy      = data.aws_iam_policy_document.terraform_state.json
  description = "Provides access to viewing, managing and updating all terraform states and locks."
}
