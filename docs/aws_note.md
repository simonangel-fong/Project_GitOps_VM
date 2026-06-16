# Terraform

```sh
# confirm AWS profile works and reaches your account
aws --profile gitops-vm sts get-caller-identity

# Confirm the state bucket exists (from Phase 0)
aws --profile gitops-vm s3 ls s3://simonangelfong-terraform-backend

cd infra
terraform init -backend-config=backend.hcl

# Validate syntax
terraform validate
# terraform plan -out=tfplan
# terraform show -json tfplan > plan.json

terraform apply tfplan
terraform apply -auto-approve

```

---

## Connect jump

```sh
ssh -i "ansible.pem" ec2-user@ip_jump
```