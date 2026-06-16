# output.tf

# ##############################
# Public IPs
# ##############################
output "jump_public_ip" {
  value       = aws_eip.jump.public_ip
  description = "Elastic IP attached to the jump host."
}

output "lb_public_ip" {
  value       = aws_eip.lb.public_ip
  description = "Elastic IP attached to the lb host."
}

# ##############################
# Private IPs (fleet)
# ##############################
output "app_vm1_private_ip" {
  value       = aws_instance.app_vm1.private_ip
  description = "Private IP of app-vm1 (canary). Reach via jump."
}

output "app_vm2_private_ip" {
  value       = aws_instance.app_vm2.private_ip
  description = "Private IP of app-vm2 (stable). Reach via jump."
}

# ##############################
# SSH command helpers
# ##############################
# Laptop -> jump (direct over the internet)
output "ssh_jump" {
  value       = "ssh -i keys/${local.project_name}.pem ubuntu@${aws_eip.jump.public_ip}"
  description = "SSH from workstation to jump host."
}

# Laptop -> lb / app VMs (through jump via ProxyJump)
output "ssh_lb" {
  value       = "ssh -i keys/${local.project_name}.pem -J ubuntu@${aws_eip.jump.public_ip} ubuntu@${aws_instance.lb.private_ip}"
  description = "SSH from workstation to lb via jump (ProxyJump)."
}

output "ssh_app_vm1" {
  value       = "ssh -i keys/${local.project_name}.pem -J ubuntu@${aws_eip.jump.public_ip} ubuntu@${aws_instance.app_vm1.private_ip}"
  description = "SSH from workstation to app-vm1 (canary) via jump (ProxyJump)."
}

output "ssh_app_vm2" {
  value       = "ssh -i keys/${local.project_name}.pem -J ubuntu@${aws_eip.jump.public_ip} ubuntu@${aws_instance.app_vm2.private_ip}"
  description = "SSH from workstation to app-vm2 (stable) via jump (ProxyJump)."
}

# Laptop -> Jenkins UI (SSH tunnel; Jenkins is bound to localhost:8080 on jump)
output "jenkins_tunnel" {
  value       = "ssh -i keys/${local.project_name}.pem -L 8080:localhost:8080 ubuntu@${aws_eip.jump.public_ip}"
  description = "Open SSH tunnel so http://localhost:8080 hits Jenkins on jump."
}
