# AWS Infrastructure Plan — Implementation Steps

| Field         | Value                                                |
| ------------- | ---------------------------------------------------- |
| Status        | Draft v1                                             |
| Author        | Simon Fong                                           |
| Last updated  | 2026-06-16                                           |
| Companion doc | [aws_design.md](aws_design.md) — what we're building |
| Scope         | Build order for the `infra/` Terraform module        |

This document is the **how**. [aws_design.md](aws_design.md) is the **what
and why** — read it first. Each phase below ends with a verification step
so you have a working slice before moving on.

## Prerequisites

Install once, locally on the workstation:

| Tool          | Min version | Purpose                              |
| ------------- | ----------- | ------------------------------------ |
| Terraform     | 1.7         | Provisioning                         |
| AWS CLI v2    | 2.15        | Credentials, S3/DynamoDB bootstrap   |
| Packer        | 1.10        | Golden AMI (Phase 2)                 |
| `jq`          | any         | Reading Terraform outputs in scripts |
| OpenSSH       | any         | Keypair generation, tunnel to Jenkins |

AWS account setup:

- An IAM user (or SSO role) with admin on `ca-central-1`.
- `aws configure --profile gitops-vm` so a named profile holds the
  credentials. The Terraform provider block references this profile by
  name so the default profile stays untouched.
- Confirm region: `aws --profile gitops-vm configure get region` → `ca-central-1`.

Local repo prep:

```
mkdir -p infra packer keys
echo "keys/" >> .gitignore
echo "*.tfstate*" >> .gitignore
echo ".terraform/" >> .gitignore
```

## Phase 0 — Remote State Bootstrap

Terraform state holds secrets (private keys, IPs) and must not live in the
repo. Standard pattern on AWS: S3 bucket for state + DynamoDB table for
locking. This phase creates them **outside** the main Terraform module
(chicken-and-egg: the module can't manage the bucket that holds its own
state).

### Steps

1. Pick globally-unique names. Suggested:
   - Bucket: `gitops-vm-tfstate-<your-initials>-<6-digit-suffix>`
   - DynamoDB table: `gitops-vm-tflock`

2. Create the bucket with versioning + encryption + public-access block,
   then the lock table. One-shot script (run once, never again):

   ```bash
   REGION=ca-central-1
   BUCKET=gitops-vm-tfstate-sf-481923    # change suffix
   TABLE=gitops-vm-tflock

   aws --profile gitops-vm s3api create-bucket \
     --bucket "$BUCKET" --region "$REGION" \
     --create-bucket-configuration LocationConstraint="$REGION"

   aws --profile gitops-vm s3api put-bucket-versioning \
     --bucket "$BUCKET" --versioning-configuration Status=Enabled

   aws --profile gitops-vm s3api put-bucket-encryption \
     --bucket "$BUCKET" --server-side-encryption-configuration \
     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

   aws --profile gitops-vm s3api put-public-access-block \
     --bucket "$BUCKET" --public-access-block-configuration \
     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

   aws --profile gitops-vm dynamodb create-table \
     --table-name "$TABLE" --region "$REGION" \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

3. Record the bucket name in `infra/backend.hcl` (gitignored — contains an
   account-specific identifier):

   ```hcl
   bucket         = "gitops-vm-tfstate-sf-481923"
   key            = "infra/terraform.tfstate"
   region         = "ca-central-1"
   dynamodb_table = "gitops-vm-tflock"
   encrypt        = true
   ```

   Add `infra/backend.hcl` to `.gitignore`. Commit a `backend.hcl.example`
   instead.

### Verification

```bash
aws --profile gitops-vm s3 ls | grep gitops-vm-tfstate
aws --profile gitops-vm dynamodb describe-table --table-name gitops-vm-tflock \
  --query 'Table.TableStatus'   # should print "ACTIVE"
```

## Phase 1 — Terraform Skeleton + Backend Init

Create the module skeleton, wire the backend, get `terraform plan` to a
clean no-op against an empty config.

### Files to create

```
infra/
├── versions.tf          terraform + provider version pins, backend block
├── providers.tf         aws provider with profile + region
├── variables.tf         admin_cidr, region (with default), name_prefix
├── terraform.tfvars     local values (gitignored)
└── terraform.tfvars.example
```

`versions.tf` — pin versions and declare the backend:

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
  backend "s3" {}   # config supplied via -backend-config=backend.hcl
}
```

`providers.tf`:

```hcl
provider "aws" {
  region  = var.region
  profile = "gitops-vm"
  default_tags {
    tags = {
      Project   = "gitops-vm"
      ManagedBy = "terraform"
    }
  }}
```

### Steps

```bash
cd infra
terraform init -backend-config=backend.hcl
terraform validate
terraform plan      # should print "No changes."
```

### Verification

```bash
aws --profile gitops-vm s3 ls "s3://$BUCKET/infra/"   # state object exists
```

## Phase 2 — Packer Golden AMI

The App subnet has no internet route, so VMs must boot from an image that
already contains everything Ansible needs. Build the AMI once; pin its ID
in `terraform.tfvars`.

### Files

```
packer/
├── al2023-base.pkr.hcl
└── README.md
```

`al2023-base.pkr.hcl` (skeleton — fill in source AMI lookup):

```hcl
packer {
  required_plugins {
    amazon = { source = "github.com/hashicorp/amazon", version = "~> 1.3" }
  }
}

source "amazon-ebs" "al2023" {
  profile       = "gitops-vm"
  region        = "ca-central-1"
  instance_type = "t3.micro"
  ssh_username  = "ec2-user"
  ami_name      = "gitops-vm-base-{{timestamp}}"
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  tags = { Project = "gitops-vm", Role = "base" }
}

build {
  sources = ["source.amazon-ebs.al2023"]
  provisioner "shell" {
    inline = [
      "sudo dnf -y update",
      "sudo dnf -y install python3 curl tar chrony",
      "sudo useradd -m -s /bin/bash appuser",
      "sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config",
      "sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
    ]
  }}
```

### Steps

```bash
cd packer
packer init al2023-base.pkr.hcl
packer validate al2023-base.pkr.hcl
packer build al2023-base.pkr.hcl     # ~5–8 min; prints the new AMI ID at end
```

Record the printed AMI ID in `infra/terraform.tfvars`:

```hcl
base_ami_id = "ami-0abc123def456789a"
```

### Verification

```bash
aws --profile gitops-vm ec2 describe-images --owners self \
  --filters "Name=tag:Project,Values=gitops-vm" \
  --query 'Images[].[ImageId,Name,CreationDate]' --output table
```

## Phase 3 — VPC, Subnets, Routing

First Terraform-managed resources. Goal: VPC with three subnets and two
route tables, no instances yet.

### Files

```
infra/
└── network.tf
```

Resources to declare (see [aws_design.md §4](aws_design.md) for the spec):

- `aws_vpc.main` — `10.0.0.0/16`, DNS hostnames + support on
- `aws_internet_gateway.main`
- `aws_subnet.dmz`  — `10.0.10.0/24`, AZ `ca-central-1a`, map_public_ip on
- `aws_subnet.app`  — `10.0.20.0/24`, AZ `ca-central-1a`, map_public_ip off
- `aws_subnet.mgmt` — `10.0.99.0/24`, AZ `ca-central-1a`, map_public_ip on
- `aws_route_table.public` — `0.0.0.0/0` → IGW
- `aws_route_table.private` — local only (no extra routes)
- `aws_route_table_association` — DMZ + Mgmt → public; App → private

Naming: tag every resource `Name = "${var.name_prefix}-<role>"` so the AWS
console reads cleanly.

### Steps

```bash
terraform plan -out tfplan
terraform apply tfplan
```

### Verification

```bash
aws --profile gitops-vm ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=gitops-vm" \
  --query 'Vpcs[].[VpcId,CidrBlock]' --output table

aws --profile gitops-vm ec2 describe-subnets \
  --filters "Name=tag:Project,Values=gitops-vm" \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,MapPublicIpOnLaunch]' \
  --output table
```

App subnet should show `MapPublicIpOnLaunch: False`.

## Phase 4 — Security Groups

Role-scoped SGs as specified in [aws_design.md §6](aws_design.md).

### Files

```
infra/
└── security.tf
```

Three SG resources (`sg-jump`, `sg-lb`, `sg-app`) plus their ingress/egress
rules as separate `aws_security_group_rule` resources (easier to diff than
inline blocks).

The non-obvious rules — easy to forget, will burn you in Phase 6:

- `sg-app` ingress 8080 from `sg-jump` (for the healthz curl)
- `sg-app` egress restricted to `10.0.0.0/16` (not all)

### Steps

```bash
terraform plan -out tfplan
terraform apply tfplan
```

### Verification

```bash
aws --profile gitops-vm ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=gitops-vm" \
  --query 'SecurityGroups[].[GroupName,GroupId]' --output table
```

## Phase 5 — Keypairs

Two keypairs as specified in [aws_design.md §9](aws_design.md): one
local-generated for laptop→jump, one Terraform-generated for jump→fleet.

### Steps

1. Generate the admin keypair locally (once):

   ```bash
   ssh-keygen -t ed25519 -f keys/gitops-admin -N "" -C "gitops-vm-admin"
   ```

2. Add to `infra/keys.tf`:

   ```hcl
   resource "aws_key_pair" "admin" {
     key_name   = "${var.name_prefix}-admin"
     public_key = file("${path.module}/../keys/gitops-admin.pub")
   }

   resource "tls_private_key" "fleet" {
     algorithm = "ED25519"
   }

   resource "aws_key_pair" "fleet" {
     key_name   = "${var.name_prefix}-fleet"
     public_key = tls_private_key.fleet.public_key_openssh
   }
   ```

3. `terraform apply`.

### Verification

```bash
aws --profile gitops-vm ec2 describe-key-pairs \
  --filters "Name=tag:Project,Values=gitops-vm" \
  --query 'KeyPairs[].[KeyName,KeyType]' --output table
```

## Phase 6 — EC2 Instances + EIPs

Four instances, two EIPs. User-data does the bare minimum:
set hostname, write `/etc/hosts`, install the fleet key into `appuser`'s
`authorized_keys` (app + LB only — jump has the private key, doesn't need
the fleet key in its own authorized_keys).

### Files

```
infra/
├── instances.tf
└── templates/
    ├── user_data_jump.sh.tftpl
    └── user_data_fleet.sh.tftpl
```

For each instance set explicitly:

- `ami           = var.base_ami_id`
- `instance_type` per the table in [aws_design.md §5](aws_design.md)
- `subnet_id`    matching the role
- `private_ip`   the static value from the design
- `vpc_security_group_ids` for the matching SG
- `key_name     = aws_key_pair.admin.key_name`  (jump only;
   fleet VMs don't need a console-attached key — they're reached via jump's
   fleet keypair injected through user_data)
- `user_data`   templatefile with the fleet public key, hostname, /etc/hosts
- `tags         = { Name = "gitops-jump" }` etc.

Two `aws_eip` + `aws_eip_association` for jump and lb.

### Steps

```bash
terraform plan -out tfplan
terraform apply tfplan
```

### Verification

```bash
terraform output jump_public_ip
ssh -i keys/gitops-admin ec2-user@$(terraform output -raw jump_public_ip) \
  'hostname && cat /etc/hosts'
```

From `jump`, confirm the fleet keypair reaches app-vm1:

```bash
# on jump
ssh appuser@app-vm1 'hostname'   # should print app-vm1
```

If this fails, check (in order): /etc/hosts on jump, sg-jump → sg-app SSH
rule, fleet private key written to `~/.ssh/id_ed25519` on jump by user_data.

## Phase 7 — Render Ansible Inventory

Close the Terraform → Ansible loop. Terraform writes
`ansible/inventory.ini` directly via `local_file`.

### Files

```
infra/
├── inventory.tf
└── templates/
    └── inventory.ini.tftpl
```

`inventory.tf`:

```hcl
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    jump_ip    = aws_instance.jump.private_ip
    lb_ip      = aws_instance.lb.private_ip
    app_vm1_ip = aws_instance.app_vm1.private_ip
    app_vm2_ip = aws_instance.app_vm2.private_ip
  })
  file_permission = "0644"
}
```

### Verification

```bash
terraform apply
cat ../ansible/inventory.ini       # hostnames per aws_design.md §8
```

## Phase 8 — Outputs

`infra/outputs.tf`:

```hcl
output "jump_public_ip" { value = aws_eip.jump.public_ip }
output "lb_public_ip"   { value = aws_eip.lb.public_ip }
output "ssh_jump"       { value = "ssh -i keys/gitops-admin ec2-user@${aws_eip.jump.public_ip}" }
output "jenkins_tunnel" { value = "ssh -i keys/gitops-admin -L 8080:localhost:8080 ec2-user@${aws_eip.jump.public_ip}" }
output "lb_url"         { value = "http://${aws_eip.lb.public_ip}" }
```

### Verification

```bash
terraform output
```

The outputs are also the start of the demo runbook — copy-paste-ready
commands for the README.

## Phase 9 — Smoke Test

End-to-end check before handing off to the Ansible layer.

```bash
# 1. Reach the jump host
eval "$(terraform output -raw ssh_jump) 'uname -a && cat /etc/hosts'"

# 2. From jump, reach every fleet VM
eval "$(terraform output -raw ssh_jump) \
  'for h in lb app-vm1 app-vm2; do ssh -o StrictHostKeyChecking=accept-new appuser@$h hostname; done'"

# 3. Confirm app VMs have NO internet
eval "$(terraform output -raw ssh_jump) \
  'ssh appuser@app-vm1 \"curl -m 5 -s -o /dev/null -w %{http_code} https://example.com || echo BLOCKED\"'"
# Expected: BLOCKED (curl times out, exits non-zero)

# 4. Confirm LB reaches app VMs on 8080 (will 502 until Ansible installs the app)
eval "$(terraform output -raw ssh_jump) \
  'ssh ec2-user@lb \"curl -m 5 -s -o /dev/null -w %{http_code} http://app-vm1:8080/\" '"
# Expected: 000 or connection refused (no app yet) — what matters is no SG block
```

If all four pass, the AWS layer is done and Ansible can take over.

## Phase 10 — Teardown

`terraform destroy` removes everything in the module. **Does not remove**:

- The S3 state bucket and DynamoDB lock table (Phase 0) — keep these
  between demo cycles so subsequent `terraform apply` runs are fast.
- The Packer AMI (Phase 2) — pinned by ID, persists in the account.

To fully wipe, after `terraform destroy`:

```bash
aws --profile gitops-vm s3 rm "s3://$BUCKET" --recursive
aws --profile gitops-vm s3api delete-bucket --bucket "$BUCKET"
aws --profile gitops-vm dynamodb delete-table --table-name gitops-vm-tflock
aws --profile gitops-vm ec2 deregister-image --image-id "$BASE_AMI_ID"
```

## Phase Order Summary

| Phase | What                  | Output                          |
| ----- | --------------------- | ------------------------------- |
| 0     | Remote state          | S3 bucket + DynamoDB table      |
| 1     | TF skeleton + init    | Empty backend, `plan` no-op     |
| 2     | Packer AMI            | `base_ami_id` recorded          |
| 3     | VPC + subnets         | Network reachable               |
| 4     | Security groups       | 3 SGs                           |
| 5     | Keypairs              | admin + fleet                   |
| 6     | EC2 + EIPs            | 4 VMs, jump SSH works           |
| 7     | Inventory render      | `ansible/inventory.ini`         |
| 8     | Outputs               | Demo commands                   |
| 9     | Smoke test            | End-to-end pass                 |
| 10    | Teardown (when done)  | Clean account                   |

After Phase 9, the AWS layer is complete. Next milestone is the Ansible
bootstrap playbook (covered in the project's main [plan.md](plan.md),
Phase A).
