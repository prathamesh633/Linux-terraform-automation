
output "instance_id" {
  value = aws_instance.web.id
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "ssh_connection_command" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/office-key.pem ec2-user@${aws_instance.web.public_ip}"
}
