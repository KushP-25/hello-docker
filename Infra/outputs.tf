output "public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.hello_ec2.public_ip
}
