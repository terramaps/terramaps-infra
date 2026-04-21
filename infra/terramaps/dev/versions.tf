terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.85.0"
    }
  }
  required_version = "~> 1.2"
  backend "s3" {
    bucket         = "terramaps-infrastructure"
    key            = "terraform/terramaps/dev.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
