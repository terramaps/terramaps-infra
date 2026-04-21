locals {
  rmq_username    = "admin" # this value cannot be changed after initial creation
  broker_protocol = split("://", "${aws_mq_broker.main.instances[0].endpoints[0]}")[0]
  broker_endpoint = split("://", "${aws_mq_broker.main.instances[0].endpoints[0]}")[1]
  celery_url      = join("", [local.broker_protocol, "://", local.rmq_username, ":", random_password.rmq.result, "@", local.broker_endpoint])
}

# To attach to instances that should be given access to rmq broker
resource "aws_security_group" "rmq_broker_access" {
  name        = "${local.deployment}-rmq-access"
  description = "${local.deployment} RabbitMQ Access Security Group"
  vpc_id      = module.vpc.vpc_id
}

# Enables egress to broker on instances with the rmq broker access group
resource "aws_security_group_rule" "rmq_broker_egress" {
  security_group_id        = aws_security_group.rmq_broker_access.id
  source_security_group_id = aws_security_group.rmq_broker.id
  type                     = "egress"
  from_port                = 5671
  to_port                  = 5671
  protocol                 = "tcp"
}

# Attached to rmq broker, allowing ingress from the rmq access group
resource "aws_security_group" "rmq_broker" {
  name        = "${local.deployment}-rmq-broker"
  description = "${local.deployment} RabbitMQ Broker Security Group"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    security_groups = ["${aws_security_group.rmq_broker_access.id}"]
  }
}

resource "random_password" "rmq" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "rmq_broker_url" {
  name        = "/${local.deployment}/secrets/rmq/brokerUrl"
  value       = local.celery_url
  description = "RabbitMQ broker URL (Celery)"
  type        = "SecureString"
}

resource "aws_mq_broker" "main" {
  broker_name                = "${local.deployment}-rmq-broker"
  engine_type                = "RabbitMQ"
  engine_version             = "3.13"
  auto_minor_version_upgrade = true
  deployment_mode            = "SINGLE_INSTANCE"
  host_instance_type         = var.amazonmq-instance-type

  publicly_accessible = false

  subnet_ids      = [module.vpc.public_subnets[0]]
  security_groups = [aws_security_group.rmq_broker.id]

  apply_immediately = true

  user {
    username = local.rmq_username
    password = random_password.rmq.result
  }

  logs {
    general = true
    audit   = false # can't audit RMQ, only ActiveMQ
  }

  encryption_options {
    use_aws_owned_key = true
  }
}
