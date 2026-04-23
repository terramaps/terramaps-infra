data "aws_ssm_parameter" "pgadmin_email" {
  name = "/terramaps-dev/secrets/admin/pgadmin/email"
}

data "aws_ssm_parameter" "pgadmin_password" {
  name = "/terramaps-dev/secrets/admin/pgadmin/password"
}

data "aws_ssm_parameter" "flower_basic_auth" {
  name = "/terramaps-dev/secrets/admin/flower/basic-auth"
}

# Admin service
module "service_admin" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.12.0"

  name        = "admin"
  family      = "${local.deployment}-admin"
  cluster_arn = module.ecs_cluster.arn

  cpu           = 512
  memory        = 1024
  desired_count = 1
  launch_type   = "FARGATE"

  enable_execute_command    = true
  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = module.ecs_cluster.task_exec_iam_role_arn

  assign_public_ip      = true # required to connect to the internet (outbound) and pull ecr image
  subnet_ids            = module.vpc.public_subnets
  create_security_group = true
  security_group_rules = {
    alb_ingress_pgadmin = {
      type                     = "ingress"
      from_port                = 8000
      to_port                  = 8000
      protocol                 = "tcp"
      source_security_group_id = aws_security_group.alb.id
    }
    alb_ingress_flower = {
      type                     = "ingress"
      from_port                = 5555
      to_port                  = 5555
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
    pgadmin = {
      target_group_arn = aws_alb_target_group.pgadmin.arn
      container_name   = "pgadmin"
      container_port   = 8000
    }
    flower = {
      target_group_arn = aws_alb_target_group.flower.arn
      container_name   = "flower"
      container_port   = 5555
    }
  }
  container_definitions = [
    {
      name                     = "pgadmin"
      image                    = "dpage/pgadmin4:9.1.0"
      essential                = true
      readonly_root_filesystem = false
      port_mappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "PGADMIN_DEFAULT_EMAIL"
          valueFrom = data.aws_ssm_parameter.pgadmin_email.arn
        },
        {
          name      = "PGADMIN_DEFAULT_PASSWORD"
          valueFrom = data.aws_ssm_parameter.pgadmin_password.arn
        },
      ]
      environment = [
        {
          name  = "PGADMIN_LISTEN_PORT"
          value = "8000"
        },
        {
          name  = "SCRIPT_NAME"
          value = "/admin/pgadmin"
        }
      ]
    },
    {
      name                     = "flower"
      image                    = "mher/flower:2.0.1"
      essential                = true
      readonly_root_filesystem = false
      port_mappings = [
        {
          containerPort = 5555
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "CELERY_BROKER_URL"
          valueFrom = aws_ssm_parameter.rmq_broker_url.arn
        },
        {
          name      = "FLOWER_BASIC_AUTH"
          valueFrom = data.aws_ssm_parameter.flower_basic_auth.arn
        },
      ]
      environment = [
        {
          name  = "FLOWER_URL_PREFIX"
          value = "admin/flower/"
        }
      ]
    }
  ]
  # TODO healthcheck
}

resource "aws_security_group_rule" "egress-alb-admin" {
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = module.service_admin.security_group_id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
}

resource "aws_alb_target_group" "pgadmin" {
  name        = "${local.deployment}-pgadmin"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/admin/pgadmin/misc/ping"
  }
}

resource "aws_lb_listener_rule" "pgadmin" {
  listener_arn = aws_alb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.pgadmin.arn
  }

  condition {
    path_pattern {
      values = ["/admin/pgadmin*"]
    }
  }
}

resource "aws_alb_target_group" "flower" {
  name        = "${local.deployment}-flower"
  port        = 5555
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/admin/flower/metrics"
  }
}

resource "aws_lb_listener_rule" "flower" {
  listener_arn = aws_alb_listener.https.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.flower.arn
  }

  condition {
    path_pattern {
      values = ["/admin/flower*"]
    }
  }
}
