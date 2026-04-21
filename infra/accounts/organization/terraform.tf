terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.85.0"
    }
  }
  required_version = "~> 1.2"

  # NOTE: the S3 bucket and DynamoDB table defined in tf-backend-store.tf must exist
  # before this backend can be used. On first apply, use a local backend, then migrate.
  backend "s3" {
    bucket         = "terramaps-infrastructure"
    key            = "terraform/accounts/terramaps.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
