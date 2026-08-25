output "vpc_id" {
  value = aws_vpc.assignment6_vpc.id
}

output "subnet_id" {
  value = aws_subnet.assignment6_subnet.id
}

output "route_table_id" {
  value = aws_route_table.assignment6_route_table.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.assignment6_igw.id
}

output "instance_id" {
  value = aws_instance.assignment6_ec2.id
}

output "instance_private_ip" {
  value = aws_instance.assignment6_ec2.private_ip
}

output "instance_public_ip" {
  value = aws_instance.assignment6_ec2.public_ip
}
output "s3_bucket_name" {
  value = aws_s3_bucket.assignment6_website.bucket
}

output "s3_website_endpoint" {
  value = aws_s3_bucket_website_configuration.assignment6_website.website_endpoint
}

output "s3_website_url" {
  value = "http://${aws_s3_bucket_website_configuration.assignment6_website.website_endpoint}"
}
output "iam_user_name" {
  value = aws_iam_user.assignment6_admin.name
}
output "nginx_instance_id" {
  value = aws_instance.nginx_server.id
}

output "nginx_public_ip" {
  value = aws_instance.nginx_server.public_ip
}

output "nginx_url" {
  value = "http://${aws_instance.nginx_server.public_ip}"
}
