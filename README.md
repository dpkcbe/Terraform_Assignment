# Deploying a Prefect Worker on ECS Fargate using Terraform

This setup provisions a Prefect 2.0 worker on AWS using ECS Fargate. The goal is to have an always-online worker that connects to Prefect Cloud, using infrastructure defined as code via Terraform. Configs like the API key are securely managed through AWS Secrets Manager.

---

## Why Terraform?

I went with Terraform because it’s flexible, easy to modularize, and widely used in the industry. It works well with AWS and makes it easy to replicate infrastructure across environments (dev, staging, prod, etc).

---

## What's in this setup?

- VPC with public & private subnets
- ECS Cluster (Fargate)
- IAM roles for ECS tasks and execution
- Secrets Manager integration (for Prefect API Key)
- Security groups, NAT gateway, and CloudWatch logging
- Prefect worker registered to a specific Work Pool

---

## How to Deploy

### Pre-Reqs

- Terraform installed
- AWS CLI configured (with permissions for ECS, IAM, VPC, Secrets Manager, etc.)
- A Prefect Cloud account (you’ll need your account & workspace ID)
- Create a secret in AWS Secrets Manager with the name `prefect-api-key-dev` and paste your Prefect API Key as the value

### 1. Clone the repo

```bash
git clone https://github.com/dpkcbe/Terraform_Assignment.git
cd Terraform_Assignment
```
### 2. Create a terraform.tfvars file with your values
prefect_account_url  = "https://api.prefect.cloud/api/accounts/your-account-id"

prefect_account_id   = "your-account-id"

prefect_workspace_id = "your-workspace-id"

You can also tweak values like the worker name, region, etc., inside variables.tf or override from CLI.

### 3. Terraform commands

#### Initialize Terraform
terraform init

#### Preview the plan
terraform plan

#### Apply the changes
terraform apply (Type yes when prompted.) OR use terraform apply --auto-approve

### 4. Verification
I - Go to ECS Console -  Check if the task is running.

II - Clusters → prefect-cluster → Tasks

III - Click on the task and check:

IV - Task Status: RUNNING

V - Launch Type: FARGATE

VI - Subnet and Security Group assigned correctly

VII - Role: Ensure both Task and Execution roles are attached

### 5.Cleaning up the resources
terraform destroy

