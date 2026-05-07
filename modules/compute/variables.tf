variable "project"            { description = "Project name prefix"; type = string }
variable "environment"        { description = "Environment name"; type = string }
variable "aws_region"         { description = "AWS region"; type = string }
variable "cluster_name"       { description = "EKS cluster name"; type = string }
variable "kubernetes_version" { description = "EKS Kubernetes version"; type = string; default = "1.31" }
variable "vpc_id"             { description = "VPC ID from the network module"; type = string }
variable "private_subnet_ids" { description = "Private subnet IDs for node groups"; type = list(string) }
variable "public_subnet_ids"  { description = "Public subnet IDs for the control plane"; type = list(string) }
variable "cluster_sg_id"      { description = "EKS control plane security group ID"; type = string }
variable "node_sg_id"         { description = "EKS node group security group ID"; type = string }
variable "node_instance_type" { description = "EC2 instance type for managed node group"; type = string; default = "t3.medium" }
variable "node_min_size"      { description = "Minimum node count"; type = number; default = 2 }
variable "node_max_size"      { description = "Maximum node count"; type = number; default = 4 }
