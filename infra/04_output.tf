output "jump_public_ip" {
  value       = aws_eip.jump.public_ip
  description = "Elastic IP attached to the jump host."
}

output "lb_public_ip" {
  value       = aws_eip.lb.public_ip
  description = "Elastic IP attached to the lb host."
}
