data "terraform_remote_state" "accounts_dev" {
  backend = "s3"
  config = {
    bucket = "terramaps-infrastructure"
    key    = "terraform/accounts/dev.tfstate"
    region = "us-east-1"
  }
}
