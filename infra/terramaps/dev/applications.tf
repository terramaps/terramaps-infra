locals {
  backend-secret-env-vars = concat(var.backend-configuration.secret-env-vars, [
    {
      name      = "CELERY_BROKER_URL"
      valueFrom = aws_ssm_parameter.rmq_broker_url.arn
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = aws_ssm_parameter.database_password.arn
    },
  ])
  backend-env-vars = concat(var.backend-configuration.env-vars, [
    {
      name  = "DB_USER"
      value = module.database.db_instance_username
    },
    {
      name  = "DB_HOST"
      value = module.database.db_instance_address
    },
    {
      name  = "DB_NAME"
      value = module.database.db_instance_name
    },
    {
      name  = "DB_PORT"
      value = module.database.db_instance_port
    },
    {
      name  = "CORS_ALLOWED_ORIGINS"
      value = "[\"https://${var.domains.app}\"]"
    },
    {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.main.bucket
    },
  ])
  images = {
    app        = "686519988262.dkr.ecr.us-east-1.amazonaws.com/terramaps/app:${var.image-version}"
    api        = "686519988262.dkr.ecr.us-east-1.amazonaws.com/terramaps/api:${var.image-version}"
    migrations = "686519988262.dkr.ecr.us-east-1.amazonaws.com/terramaps/migrations:${var.image-version}"
    worker     = "686519988262.dkr.ecr.us-east-1.amazonaws.com/terramaps/worker:${var.image-version}"
  }
}

# ECS cluster
module "ecs_cluster" {
  source       = "terraform-aws-modules/ecs/aws//modules/cluster"
  version      = "5.12.0"
  cluster_name = "${local.deployment}-cluster"

  create_task_exec_iam_role = true
  task_exec_ssm_param_arns  = ["arn:aws:ssm:*:*:parameter/${local.deployment}/*"]

  cloudwatch_log_group_name   = "${local.deployment}/services"
  create_cloudwatch_log_group = true
}

# App frontend service
module "service_app" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.12.0"

  name        = "app"
  family      = "${local.deployment}-app"
  cluster_arn = module.ecs_cluster.arn

  cpu                      = var.app-configuration.cpu
  memory                   = var.app-configuration.memory
  desired_count            = var.app-configuration.replicas
  autoscaling_max_capacity = var.app-configuration.max-replicas
  launch_type              = "FARGATE"

  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = module.ecs_cluster.task_exec_iam_role_arn

  assign_public_ip      = true # need to connect to internet for ECR
  subnet_ids            = module.vpc.public_subnets
  create_security_group = true
  security_group_rules = {
    alb_ingress = {
      type                     = "ingress"
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.alb.id
    }
    internet_egress = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  load_balancer = {
    service = {
      target_group_arn = aws_alb_target_group.app.arn
      container_name   = "app"
      container_port   = 80
    }
  }
  container_definitions = [
    {
      name                     = "app"
      image                    = local.images.app
      essential                = true
      readonly_root_filesystem = false
      environment              = var.app-configuration.env-vars
      port_mappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
    }
  ]
}

# API service
module "service_api" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.12.0"

  name        = "api"
  family      = "${local.deployment}-api"
  cluster_arn = module.ecs_cluster.arn

  cpu                      = var.api-configuration.cpu
  memory                   = var.api-configuration.memory
  desired_count            = var.api-configuration.replicas
  autoscaling_max_capacity = var.api-configuration.max-replicas
  launch_type              = "FARGATE"

  enable_execute_command    = true
  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = module.ecs_cluster.task_exec_iam_role_arn
  tasks_iam_role_policies = {
    s3_public_write  = aws_iam_policy.s3_public_write_policy.arn
    s3_private_write = aws_iam_policy.s3_private_write_policy.arn
    s3_private_read  = aws_iam_policy.s3_private_read_policy.arn
    s3_secrets_read  = aws_iam_policy.s3_secrets_read_policy.arn
  }

  assign_public_ip      = true # required to connect to the internet (outbound)
  subnet_ids            = module.vpc.public_subnets
  create_security_group = true
  security_group_rules = {
    alb_ingress = {
      type                     = "ingress"
      from_port                = 8000
      to_port                  = 8000
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.alb.id
    }
    internet_egress = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  security_group_ids = [
    aws_security_group.database_access.id,
    aws_security_group.rmq_broker_access.id
  ]
  load_balancer = {
    service = {
      target_group_arn = aws_alb_target_group.api.arn
      container_name   = "api"
      container_port   = 8000
    }
  }
  container_definitions = [
    merge({
      name                     = "migrations"
      image                    = local.images.migrations
      essential                = false
      readonly_root_filesystem = false
      environment              = concat(local.backend-env-vars, [{ name = "ALEMBIC_CONFIG", value = "./src/migrations/alembic.ini" }])
      secrets                  = local.backend-secret-env-vars
      start_timeout            = (var.run-manual-migrations || var.long-migration-timeout) ? 86400 : 1200
      },
      var.use-migration-secrets ? {
        entrypoint = ["/bin/sh", "-c"]
        command    = ["/app/.venv/bin/aws s3 sync s3://$S3_BUCKET/secrets/ /app/src/migrations/data/secret/ && exec /app/.venv/bin/alembic upgrade head"]
      } : {},
      # If run-manual-migrations is true, we sleep forever (until ECS times us out)
      # while we can manually exec into the container to run migrations in a custom fashion.
      # Once the manual migration is done, `touch /tmp/done` in the container to signal success.
      var.run-manual-migrations ? {
        entrypoint = ["/bin/sh"]
        command = [
          "-c",
          "echo 'Waiting for /tmp/done...'; while [ ! -f /tmp/done ]; do sleep 30; done; echo 'Done signal received.'",
        ]
      } : {}
    ),
    {
      name                     = "api"
      image                    = local.images.api
      essential                = true
      readonly_root_filesystem = false
      environment              = local.backend-env-vars
      secrets                  = local.backend-secret-env-vars
      port_mappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      dependencies = [{
        containerName = "migrations"
        condition     = "SUCCESS"
      }]
    }
  ]
}

# Celery worker service
module "service_worker" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.12.0"

  name        = "worker"
  family      = "${local.deployment}-worker"
  cluster_arn = module.ecs_cluster.arn

  cpu                      = var.worker-configuration.cpu
  memory                   = var.worker-configuration.memory
  desired_count            = var.worker-configuration.replicas
  autoscaling_max_capacity = var.worker-configuration.max-replicas
  launch_type              = "FARGATE"

  enable_execute_command    = true
  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = module.ecs_cluster.task_exec_iam_role_arn
  tasks_iam_role_policies = {
    s3_public_write  = aws_iam_policy.s3_public_write_policy.arn
    s3_private_write = aws_iam_policy.s3_private_write_policy.arn
    s3_private_read  = aws_iam_policy.s3_private_read_policy.arn
  }

  assign_public_ip      = true # required to connect to the internet (outbound) and pull ECR image
  subnet_ids            = module.vpc.public_subnets
  create_security_group = true
  security_group_rules = {
    internet_egress = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  security_group_ids = [
    aws_security_group.database_access.id,
    aws_security_group.rmq_broker_access.id
  ]
  container_definitions = [
    {
      name                     = "worker"
      image                    = local.images.worker
      essential                = true
      readonly_root_filesystem = false
      environment              = local.backend-env-vars
      secrets                  = local.backend-secret-env-vars
      command = [
        "--app",
        "src.workers:celery_app",
        "worker",
        "--queues",
        "terramaps",
        "-n",
        "worker@%h"
      ]
      health_check = {
        command      = ["CMD-SHELL", "/app/.venv/bin/celery inspect ping -d worker@$HOSTNAME"]
        interval     = 60
        timeout      = 30
        retries      = 3
        start_period = 60
      }
    }
  ]
}
