variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "ecs_cluster_name" {
  default = "prefect-cluster"
  type        = string
}

variable "prefect_account_id" {}
variable "prefect_workspace_id" {}
variable "prefect_account_url" {}