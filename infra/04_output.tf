output "al2023_ami_id" {
  value       = data.aws_ami.al2023.id
  description = "AMI ID resolved for the fleet base image."
}
