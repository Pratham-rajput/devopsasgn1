# Outputs will be added after EC2, RDS,
# VPC peering and NAT resources are defined.

output "web_public_ip" {
  description = "Public IP of the Web EC2"
  value       = aws_instance.web.public_ip
}

output "app_private_ip" {
  description = "Private IP of the App EC2"
  value       = aws_instance.app.private_ip
}

output "db_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.nimbuscart.endpoint
}

output "web_vpc_id" {
  description = "Web VPC ID"
  value       = aws_vpc.web.id
}

output "data_vpc_id" {
  description = "Data VPC ID"
  value       = aws_vpc.data.id
}

output "frontend_url" {
  description = "NimbusCart frontend URL"
  value       = "http://${aws_instance.web.public_ip}"
}
