# Create ACM certs
resource "aws_acm_certificate" "app" {
  domain_name       = var.domains.app
  validation_method = "DNS"
}

resource "aws_acm_certificate" "api" {
  domain_name       = var.domains.api
  validation_method = "DNS"
}

# Validate certs
resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for record in aws_route53_record.app-validation : record.fqdn]
}
resource "aws_route53_record" "app-validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.terraform_remote_state.accounts_dev.outputs.app_zone_id
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.api-validation : record.fqdn]
}
resource "aws_route53_record" "api-validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.terraform_remote_state.accounts_dev.outputs.api_zone_id
}

## Load balancer

# Security group — shared by app and api since they share the ALB
resource "aws_security_group" "alb" {
  name        = "${local.deployment}-alb"
  description = "Controls access to the ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "egress-app" {
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = module.service_app.security_group_id
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "egress-api" {
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = module.service_api.security_group_id
  type                     = "egress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
}

# Single load balancer for all externally-facing services
resource "aws_alb" "main" {
  name            = "${local.deployment}-alb"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.alb.id]
}

# Target groups
resource "aws_alb_target_group" "app" {
  name        = "${local.deployment}-app"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
}

resource "aws_alb_target_group" "api" {
  name        = "${local.deployment}-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/heartbeat"
  }
}

# HTTPS listener — default routes to app, host-based rule routes api.* to API target group
resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.app.arn
  }
}

# Attach the API cert so the ALB can terminate TLS for both domains
resource "aws_alb_listener_certificate" "api" {
  listener_arn    = aws_alb_listener.https.arn
  certificate_arn = aws_acm_certificate.api.arn
}

# Route api.* hostname to the API target group
resource "aws_alb_listener_rule" "api" {
  listener_arn = aws_alb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.api.arn
  }
  condition {
    host_header {
      values = [var.domains.api]
    }
  }
}

# HTTP → HTTPS redirect
resource "aws_alb_listener" "redirect" {
  load_balancer_arn = aws_alb.main.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# DNS A records — both point to the same ALB
resource "aws_route53_record" "app" {
  zone_id = data.terraform_remote_state.accounts_dev.outputs.app_zone_id
  name    = var.domains.app
  type    = "A"
  alias {
    name                   = aws_alb.main.dns_name
    zone_id                = aws_alb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.terraform_remote_state.accounts_dev.outputs.api_zone_id
  name    = var.domains.api
  type    = "A"
  alias {
    name                   = aws_alb.main.dns_name
    zone_id                = aws_alb.main.zone_id
    evaluate_target_health = true
  }
}
