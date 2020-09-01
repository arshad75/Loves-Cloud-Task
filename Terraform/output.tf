output "aws_security_group_http_server_details" {
  value = aws_security_group.public_security_group
}

output "http_server_public_dns" {
  value = aws_instance.prod_instance.public_dns
}