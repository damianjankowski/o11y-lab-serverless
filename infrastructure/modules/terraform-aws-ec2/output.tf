output "private_key_pem" {
  value     = tls_private_key.generated_key.private_key_pem
  sensitive = true
}

output "instance_public_ip" {
  value       = aws_instance.instance.public_ip
  description = "Public IP address of the EC2 instance"
}

output "instance_id" {
  value       = aws_instance.instance.id
  description = "ID of the EC2 instance"
}

output "vpc_id" {
  value       = aws_vpc.main_vpc.id
  description = "ID of the VPC"
}

output "subnet_id" {
  value       = aws_subnet.public_subnet.id
  description = "ID of the public subnet"
}

output "security_group_id" {
  value       = aws_security_group.activegate_sg.id
  description = "ID of the security group"
}

output "key_pair_name" {
  value       = aws_key_pair.ec2_key.key_name
  description = "Name of the EC2 key pair"
}
