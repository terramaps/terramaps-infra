resource "aws_route53_zone" "app" {
  name = "demo.terramaps.us"
}

resource "aws_route53_zone" "api" {
  name = "api-demo.terramaps.us"
}

output "app_zone_id" {
  description = "Route53 hosted zone ID for demo.terramaps.us"
  value       = aws_route53_zone.app.zone_id
}

output "api_zone_id" {
  description = "Route53 hosted zone ID for api-demo.terramaps.us"
  value       = aws_route53_zone.api.zone_id
}
