variable "project"      { description = "Project name used as prefix for all resources"; type = string }
variable "environment"  { description = "Deployment environment name (dev, staging, prod)"; type = string }
variable "aws_region"   { description = "AWS region where network resources are created"; type = string }
variable "cluster_name" { description = "EKS cluster name used to tag subnets for Kubernetes discovery"; type = string }
variable "vpc_cidr"     {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation  { condition = can(cidrhost(var.vpc_cidr, 0)); error_message = "Must be a valid CIDR block." }
}
