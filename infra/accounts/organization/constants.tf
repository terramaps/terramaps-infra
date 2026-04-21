locals {
  # ECR repositories to create in the organization account.
  # These must match the image names referenced in infra/terramaps/*/applications.tf.
  ecr_repos = [
    "terramaps/app",
    "terramaps/api",
    "terramaps/migrations",
    "terramaps/worker",
  ]

  # All AWS account IDs where deployments can pull ECR images.
  aws_workspaces = [
    "336519019521"
  ]
}
