# Compute module: EKS cluster (API auth mode), managed node group in private subnets,
# Pod Identity addon, AWS Load Balancer Controller IAM, and cluster addons.

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

locals {
  tags = { Project = var.project; Environment = var.environment; ManagedBy = "terraform" }
}

# EKS cluster IAM role
resource "aws_iam_role" "cluster" {
  name = "${var.project}-${var.environment}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Principal = { Service = "eks.amazonaws.com" }; Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# KMS key for encrypting EKS secrets
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secret encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(local.tags, { Name = "${var.project}-${var.environment}-eks-kms" })
}

# EKS cluster with API authentication mode and both endpoint types enabled
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [var.cluster_sg_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  encryption_config {
    provider   { key_arn = aws_kms_key.eks.arn }
    resources  = ["secrets"]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
  tags       = merge(local.tags, { Name = var.cluster_name })
}

# Core EKS addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = local.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on               = [aws_eks_node_group.main]
  tags                     = local.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = local.tags
}

# Pod Identity Agent addon - enables Pod Identity (replaces IRSA)
resource "aws_eks_addon" "pod_identity" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = local.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on               = [aws_eks_node_group.main]
  tags                     = local.tags
}

# Node group IAM role
resource "aws_iam_role" "nodes" {
  name = "${var.project}-${var.environment}-eks-nodes-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Principal = { Service = "ec2.amazonaws.com" }; Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "nodes_worker"  { role = aws_iam_role.nodes.name; policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" }
resource "aws_iam_role_policy_attachment" "nodes_cni"     { role = aws_iam_role.nodes.name; policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" }
resource "aws_iam_role_policy_attachment" "nodes_ecr"     { role = aws_iam_role.nodes.name; policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" }
resource "aws_iam_role_policy_attachment" "nodes_ebs"     { role = aws_iam_role.nodes.name; policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" }

# KMS key for node group EBS encryption
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EKS node group EBS volumes"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(local.tags, { Name = "${var.project}-${var.environment}-ebs-kms" })
}

# Launch template enforces IMDSv2 and EBS encryption
resource "aws_launch_template" "nodes" {
  name_prefix   = "${var.project}-${var.environment}-node-"
  instance_type = var.node_instance_type

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs.arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${var.project}-${var.environment}-node" })
  }
}

# Managed node group in private subnets only
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  launch_template { id = aws_launch_template.nodes.id; version = "$Latest" }

  scaling_config {
    desired_size = var.node_min_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config { max_unavailable = 1 }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
    aws_eks_addon.vpc_cni
  ]

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-nodes" })

  lifecycle { ignore_changes = [scaling_config[0].desired_size] }
}

# AWS Load Balancer Controller IAM role bound via Pod Identity
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.project}-${var.environment}-alb-controller"
  description = "IAM policy for the AWS Load Balancer Controller"
  policy      = file("${path.module}/alb-controller-policy.json")
}

resource "aws_iam_role" "alb_controller" {
  name = "${var.project}-${var.environment}-alb-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# Pod Identity association for the ALB controller service account
resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb_controller.arn
}
