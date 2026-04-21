aws-provider = {
  id          = 336519019521
  assume-role = "arn:aws:iam::336519019521:role/github/deploy_role"
}

stack = "dev"

subdomains = {
  app = "demo" # demo.terramaps.us / api-demo.terramaps.us
}

rds-configuration = {
  instance-type     = "db.t4g.micro"
  allocated-storage = 40
}

amazonmq-instance-type = "mq.t3.micro"

image-version = "latest"

app-configuration = {
  cpu      = 256
  memory   = 512
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
  cpu          = 256
  memory       = 512
  replicas     = 1
  max-replicas = 1
}

worker-configuration = {
  cpu          = 512
  memory       = 1024
  replicas     = 1
  max-replicas = 2
}
