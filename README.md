# AWS EC2 Infrastructure with Terraform

A clean, modular Terraform configuration to provision a public EC2 instance within an isolated AWS VPC, complete with dynamic SSH key generation, security group rules, and routing configuration.

---

## 🏗️ Architecture Overview

The infrastructure deployed by this Terraform project is structured as follows:

```
[ Local Machine ]
  │
  ├── Private SSH Key (terraform-ec2-key.pem)
  │
  ▼ (SSH Access on Port 22)
[ AWS Cloud : region = eu-north-1 ]
  │
  └── AWS VPC (10.0.0.0/16)
        │
        ├── Internet Gateway (terraform-igw)
        │     │ (Routes internet traffic: 0.0.0.0/0)
        │     ▼
        ├── Route Table (terraform-public-route-table)
        │     │ (Associated with)
        │     ▼
        ├── Public Subnet (10.0.1.0/24)
        │     │
        │     └── EC2 Instance (terraform-t3-small)
        │           ├── AMI: Amazon Linux 2023
        │           ├── Instance Type: t3.micro
        │           ├── Security Group: terraform-ec2-sg (Allows SSH:22)
        │           └── Key Pair: terraform-ec2-key
        │
        └── AWS Key Pair & Security Group
```

### Resource Flow & Network Hierarchy

1. **VPC Network**: An isolated network container (`10.0.0.0/16`) created in AWS.
2. **Internet Access**: An **Internet Gateway** is attached to the VPC to enable internet connectivity.
3. **Subnet & Routing**: A **Public Subnet** (`10.0.1.0/24`) is linked to a **Route Table** that routes `0.0.0.0/0` traffic through the Internet Gateway.
4. **Compute Instance**: An **EC2 Instance** (`t3.micro`) runs inside the Public Subnet with an auto-assigned public IP address.
5. **Security & Key Management**:
   - A **TLS RSA Key Pair** is dynamically generated during deployment.
   - The public key is registered in AWS as an **AWS Key Pair** and attached to the EC2 instance.
   - The private key is saved locally to `terraform-ec2-key.pem` with `0600` file permissions.
   - A **Security Group** acts as a virtual firewall allowing inbound SSH (port 22) traffic and all outbound traffic.

---

## 📦 Created Resources & Their Relationships

| Resource Type | Resource Name in Terraform | Purpose & Description | Relations / Dependencies |
| :--- | :--- | :--- | :--- |
| **AWS VPC** | `aws_vpc.main` | Isolated virtual network (`10.0.0.0/16`). | Root network container for all subnets, gateways, and security groups. |
| **Internet Gateway** | `aws_internet_gateway.main` | Gateway providing internet access to resources inside the VPC. | Attached to `aws_vpc.main`. |
| **Public Subnet** | `aws_subnet.public` | Subnet segment (`10.0.1.0/24`) configured to auto-assign public IPs. | Located inside `aws_vpc.main` across an active Availability Zone. |
| **Route Table** | `aws_route_table.public` | Routing rules directing all outbound internet traffic (`0.0.0.0/0`) to the Internet Gateway. | Linked to `aws_vpc.main` and targets `aws_internet_gateway.main`. |
| **Route Association** | `aws_route_table_association.public` | Associates the public route table with the public subnet. | Connects `aws_subnet.public` to `aws_route_table.public`. |
| **TLS Key Generator** | `tls_private_key.ssh` | Generates a secure 4096-bit RSA key pair locally during deployment. | Supplies public key to `aws_key_pair` and private key to `local_file`. |
| **AWS Key Pair** | `aws_key_pair.ssh` | Registers the generated public SSH key in AWS. | Attached to `aws_instance.server` for SSH authentication. |
| **Local Private Key File** | `local_file.private_key` | Saves the private key to `terraform-ec2-key.pem` locally with `0600` permissions. | Receives key data from `tls_private_key.ssh`. |
| **Security Group** | `aws_security_group.ec2` | Virtual firewall allowing inbound SSH (port 22) and unrestricted egress. | Attached to `aws_instance.server` within `aws_vpc.main`. |
| **AMI Data Source** | `data.aws_ami.amazon_linux` | Queries AWS for the latest Amazon Linux 2023 AMI ID dynamically. | Provides AMI ID to `aws_instance.server`. |
| **AZ Data Source** | `data.aws_availability_zones.available` | Discovers available availability zones in the region. | Assigns AZ to `aws_subnet.public`. |
| **EC2 Instance** | `aws_instance.server` | The virtual server compute instance (`t3.micro`). | Placed inside `aws_subnet.public`, secured by `aws_security_group.ec2`, uses `aws_key_pair.ssh`. Depends on `aws_internet_gateway.main`. |

---

## 📁 Terraform Files & Directory Lifecycle Guide

Understanding what each file does and when it is created is key to mastering Terraform.

```
terraform/
├── 📄 provider.tf                # Provider definitions & version locks
├── 📄 variables.tf               # Input variable declarations
├── 📄 main.tf                    # Primary resource definitions
├── 📄 outputs.tf                  # Output values & connection instructions
├── 📄 .gitignore                 # Files excluded from version control
│
├── 📁 .terraform/                # ⚡ Created after `terraform init`
├── 📄 .terraform.lock.hcl        # ⚡ Created after `terraform init`
│
├── 📄 terraform.tfstate          # 🚀 Created after `terraform apply`
├── 📄 terraform.tfstate.backup   # 🚀 Created after `terraform apply`
└── 🔑 terraform-ec2-key.pem      # 🚀 Created after `terraform apply` (via local_file)
```

### 1. Source Configuration Files (Written by You)

* **`provider.tf`**:
  * Configures required Terraform providers (`hashicorp/aws`, `hashicorp/tls`, `hashicorp/local`) and sets version constraints.
  * Specifies the AWS region using `var.aws_region`.
* **`variables.tf`**:
  * Defines configurable inputs with defaults:
    * `aws_region` (Default: `eu-north-1`)
    * `instance_type` (Default: `t3.micro`)
    * `vpc_cidr` (Default: `10.0.0.0/16`)
    * `subnet_cidr` (Default: `10.0.1.0/24`)
* **`main.tf`**:
  * Contains the core resource declarations for the AWS network, security group, SSH keys, local key saving, and the EC2 instance.
* **`outputs.tf`**:
  * Exposes useful deployment details after apply: VPC ID, Subnet ID, Security Group ID, Instance ID, Public IP, Public DNS, and a ready-to-use SSH login command.

---

### 2. Files Created After `terraform init`

When you run `terraform init`, Terraform prepares your working directory:

* **`.terraform/` (Directory)**:
  * Contains downloaded provider plugin binaries (`hashicorp/aws`, `hashicorp/tls`, `hashicorp/local`).
  * *Do not commit this folder to Git.*
* **`.terraform.lock.hcl`**:
  * The Dependency Lock File. It records the exact provider versions and cryptographic hashes used.
  * *Commit this file to Git* to guarantee reproducible builds across team members and CI/CD pipelines.

---

### 3. Files Created After `terraform apply`

When you run `terraform apply`, Terraform provisions real resources and generates state/key artifacts:

* **`terraform.tfstate`**:
  * **The single source of truth for your infrastructure.** Maps your `.tf` configuration declarations to actual AWS resource IDs and metadata.
  * Contains sensitive values in plain text (e.g., generated private SSH key data).
  * *Never commit this file to public Git repositories!*
* **`terraform.tfstate.backup`**:
  * A snapshot of the state file prior to the most recent `terraform apply` or `terraform destroy` run. Allows recovery if an apply fails.
* **`terraform-ec2-key.pem`**:
  * Generated locally by the `local_file.private_key` resource in `main.tf`.
  * Contains the private key needed to SSH into the EC2 instance (permissions automatically set to `0600`).

---

### 4. Git Ignore Rules (`.gitignore`)

Safety is critical when managing infrastructure as code:
* Excludes `.terraform/` plugins (large binary files).
* Excludes state files (`*.tfstate`, `*.tfstate.*`) to prevent exposing secrets and credentials.
* Excludes private key files (`*.pem`, `*.key`) to prevent leaking private SSH keys.

---

## 🚀 Step-by-Step Workflow Commands

### 1. Initialize Working Directory
Downloads required provider plugins and creates `.terraform/` and `.terraform.lock.hcl`.
```bash
terraform init
```

### 2. Format & Validate Configuration
Ensures clean code style and validates syntax.
```bash
terraform fmt
terraform validate
```

### 3. Preview Execution Plan
Shows what resources will be created, modified, or destroyed before making changes in AWS.
```bash
terraform plan
```

### 4. Apply & Provision Infrastructure
Executes the plan to create AWS resources and saves local private key.
```bash
terraform apply
```

### 5. Connect to EC2 Instance
Use the SSH output command generated by Terraform:
```bash
ssh -i terraform-ec2-key.pem ec2-user@<instance_public_ip>
```
*(Or run directly using Terraform output: `ssh -i terraform-ec2-key.pem ec2-user@$(terraform output -raw public_ip)`)*

### 6. Destroy Infrastructure
Deletes all created resources in AWS to clean up and avoid unnecessary costs.
```bash
terraform destroy
```

---

## 📊 Summary Outputs Reference

| Output Name | Description |
| :--- | :--- |
| `vpc_id` | AWS VPC Identifier |
| `subnet_id` | Public Subnet Identifier |
| `security_group_id` | EC2 Security Group Identifier |
| `instance_id` | EC2 Instance ID |
| `public_ip` | Assigned Public IPv4 Address |
| `public_dns` | Assigned Public DNS Hostname |
| `ssh_command` | Pre-formatted terminal SSH command |
