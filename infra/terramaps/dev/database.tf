# To attach to instances that should be given access to the database
resource "aws_security_group" "database_access" {
  name        = "${local.deployment}-database-access-sg"
  description = "${local.deployment} Database Access Security Group"
  vpc_id      = module.vpc.vpc_id
}

# Enables egress to database on instances with the db access group
resource "aws_security_group_rule" "database_egress" {
  security_group_id        = aws_security_group.database_access.id
  source_security_group_id = aws_security_group.database.id
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
}

# Attached to the db, allowing ingress from the database access group
resource "aws_security_group" "database" {
  name        = "${local.deployment}-database-sg"
  description = "${local.deployment} Database Security Group"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["${aws_security_group.database_access.id}"]
  }
}

resource "random_password" "database" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "database_password" {
  name        = "/${local.deployment}/secrets/database/masterPassword"
  value       = random_password.database.result
  description = "Postgres master password"
  type        = "SecureString"
}

module "database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0"

  identifier                 = "${local.deployment}-database"
  instance_class             = var.rds-configuration.instance-type
  engine                     = "postgres"
  major_engine_version       = "16"
  auto_minor_version_upgrade = true
  allocated_storage          = var.rds-configuration.allocated-storage
  family                     = "postgres16"

  port    = 5432
  db_name = "terramaps"

  username                    = "terramaps_admin"
  password                    = aws_ssm_parameter.database_password.value
  manage_master_user_password = false

  create_db_option_group    = false
  create_db_parameter_group = false

  publicly_accessible    = false
  create_db_subnet_group = true
  subnet_ids             = module.vpc.public_subnets
  vpc_security_group_ids = [aws_security_group.database.id]
  multi_az               = false

  backup_retention_period      = 30
  performance_insights_enabled = true
  create_monitoring_role       = true
  monitoring_interval          = 60
  monitoring_role_name         = "${local.deployment}-rds-monitoring-role"
}
