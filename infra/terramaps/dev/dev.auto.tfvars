aws-provider = {
  id          = 336519019521
  assume-role = "arn:aws:iam::336519019521:role/github/deploy_role"
}

stack = "dev"

domains = {
  app = "demo.terramaps.us"
  api = "api-demo.terramaps.us"
}

rds-configuration = {
  instance-type     = "db.m6g.xlarge"
  allocated-storage = 100
}

amazonmq-instance-type = "mq.m7g.medium"

image-version = "latest"

use-migration-secrets = false

app-configuration = {
  cpu      = 1024
  memory   = 2048
  replicas = 1
  env-vars = [
    { name = "API_BASE_URL", value = "https://api-demo.terramaps.us" },
  ]
}

backend-configuration = {
  env-vars = [
    { name = "LOG_LEVEL", value = "DEBUG" },
    { name = "JWT_ALGORITHM", value = "HS256" },
    { name = "JWT_ACCESS_TOKEN_EXPIRE_MINUTES", value = "180" },
    { name = "JWT_COOKIE_SECURE", value = "true" },
  ]
  secret-env-vars = [
    {
      name      = "JWT_SECRET"
      valueFrom = "arn:aws:ssm:us-east-1:336519019521:parameter/terramaps-dev/secrets/jwt/secret"
    },
  ]
}

api-configuration = {
  cpu          = 2048
  memory       = 4096
  replicas     = 2
  max-replicas = 2
}

worker-configuration = {
  cpu          = 2048
  memory       = 4096
  replicas     = 1
  max-replicas = 1
}
