# AWS EC2 Provisioning with Terraform

This directory contains Terraform code to provision an AWS EC2 t2.medium instance with a 12GB root EBS volume, security group, and user data to install Node.js and Docker.

## Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) installed
- AWS credentials configured (via environment variables, AWS CLI, or credentials file)

## Usage

1. Initialize Terraform:
   ```sh
   terraform init
   ```

2. Review the plan:
   ```sh
   terraform plan
   ```

3. Apply the configuration:
   ```sh
   terraform apply
   ```
   - Confirm with `yes` when prompted.

4. After creation, Terraform will output the public IP of the instance.

## Connecting to the Instance
- By default, SSH (port 22) and HTTP (port 80) are open to the world.
- You may want to add a `key_name` to the `aws_instance` resource to use your SSH key for access.

## Customization
- Edit `user_data.sh` to install additional software as needed.
- Change the region, AMI, or instance type in `main.tf` as required. 