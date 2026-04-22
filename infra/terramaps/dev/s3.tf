resource "aws_s3_bucket" "main" {
  bucket = local.deployment
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_iam_policy" "s3_private_read_policy" {
  name        = "${local.deployment}-private-read-policy"
  description = "Allow private objects read access."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "s3:GetObject",
        Resource = "${aws_s3_bucket.main.arn}/private/*",
      }
    ]
  })
}

resource "aws_iam_policy" "s3_private_write_policy" {
  name        = "${local.deployment}-private-write-policy"
  description = "Allow private objects write access."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.main.arn}/private/*",
      }
    ]
  })
}

resource "aws_iam_policy" "s3_public_write_policy" {
  name        = "${local.deployment}-public-write-policy"
  description = "Allow write access to public objects."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.main.arn}/public/*",
      }
    ]
  })
}

resource "aws_iam_policy" "s3_secrets_read_policy" {
  name        = "${local.deployment}-secrets-read-policy"
  description = "Allow secrets read access for migrations."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["s3:GetObject", "s3:ListBucket"],
      Resource = [
        "${aws_s3_bucket.main.arn}/secrets/*",
        aws_s3_bucket.main.arn,
      ]
    }]
  })
}

resource "aws_s3_bucket_policy" "main" {
  bucket     = aws_s3_bucket.main.id
  depends_on = [aws_s3_bucket_public_access_block.main]
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.main.arn}/public/*",
      },
    ],
  })
}
