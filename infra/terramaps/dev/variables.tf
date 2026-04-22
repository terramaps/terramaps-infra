variable "aws-provider" {
  description = "Provider details for AWS account that provides main deployment."
  type = object({
    id          = number # workspace id
    assume-role = string # arn
  })
}

variable "stack" {
  description = "Name of the stack"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["prod", "dev"], var.stack)
    error_message = "stack must be one of prod or dev"
  }
}

variable "aws-region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Route 53 configuration
variable "subdomains" {
  description = "Sub domain name. e.g. app will be app.terramaps.us."
  type = object({
    app = string
    api = optional(string)
  })
  nullable = false
}

# Application configuration
### Version of the docker image to deploy
variable "image-version" {
  description = "Version of the docker images to deploy. Used by app, api, migrations, and worker images."
  type        = string
  nullable    = false
}

### Manual migrations
variable "run-manual-migrations" {
  description = "When set to true, the migrations in the api service will sleep forever allowing an engineer to exec into the container to run the migrations in a custom fashion."
  type        = bool
  default     = false
}

### Migration secrets
variable "use-migration-secrets" {
  description = "When set to true, the migrations container will sync secrets from S3 before running."
  type        = bool
  default     = false
}

### Long migration timeout
variable "long-migration-timeout" {
  description = "When set to true, the migrations container start_timeout is set to 1 day (86400s) instead of the default 1200s."
  type        = bool
  default     = false
}

### App service
variable "app-configuration" {
  description = "Defines the app compute resources with memory (MB) and CPU (vCPU)"
  nullable    = false
  type = object({
    memory       = number
    cpu          = number
    replicas     = number
    max-replicas = optional(number, 10)
    env-vars = list(object({
      name  = string
      value = string
    }))
  })
}

# Common backend configuration
variable "backend-configuration" {
  description = "Defines common configuration for backend services (api and worker)"
  nullable    = false
  type = object({
    env-vars = list(object({
      name  = string
      value = string
    }))
    secret-env-vars = list(object({
      name      = string
      valueFrom = string
    }))
  })
}

# API service
variable "api-configuration" {
  description = "Defines the api compute resources with memory (MB) and CPU (vCPU)"
  nullable    = false
  type = object({
    memory       = number
    cpu          = number
    replicas     = number
    max-replicas = optional(number, 10)
  })
}

# Worker service
variable "worker-configuration" {
  description = "Defines the celery worker compute resources with memory (MB) and CPU (vCPU)"
  nullable    = false
  type = object({
    memory       = number
    cpu          = number
    replicas     = number
    max-replicas = optional(number, 10)
  })
}

# RDS configuration
variable "rds-configuration" {
  description = "RDS instance configuration"
  type = object({
    instance-type     = string
    allocated-storage = number # in GB
  })
  nullable = false
}

# AmazonMQ configuration
variable "amazonmq-instance-type" {
  description = "AmazonMQ instance type"
  type        = string
  nullable    = false
}
