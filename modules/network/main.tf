# Network module: VPC, public and private subnets across 3 AZs,
# IGW, NAT Gateway, route tables, and security groups for EKS and ALB.

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

data "aws_availability_zones" "available" { state = "available" }

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, {
    Name = "${var.project}-${var.environment}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.project}-${var.environment}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name                                        = "${var.project}-${var.environment}-public-${local.azs[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = local.azs[count.index]
  tags = merge(local.tags, {
    Name                                        = "${var.project}-${var.environment}-private-${local.azs[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = merge(local.tags, { Name = "${var.project}-${var.environment}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags          = merge(local.tags, { Name = "${var.project}-${var.environment}-nat" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.main.id }
  tags   = merge(local.tags, { Name = "${var.project}-${var.environment}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0"; nat_gateway_id = aws_nat_gateway.main.id }
  tags   = merge(local.tags, { Name = "${var.project}-${var.environment}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project}-${var.environment}-eks-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.main.id
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]; description = "Allow all outbound" }
  tags        = merge(local.tags, { Name = "${var.project}-${var.environment}-eks-cluster-sg" })
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project}-${var.environment}-eks-nodes-sg"
  description = "EKS worker nodes security group"
  vpc_id      = aws_vpc.main.id
  ingress { from_port = 0; to_port = 0; protocol = "-1"; self = true; description = "Inter-node communication" }
  ingress { from_port = 1025; to_port = 65535; protocol = "tcp"; security_groups = [aws_security_group.eks_cluster.id]; description = "Control plane to node kubelets" }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]; description = "Allow all outbound" }
  tags        = merge(local.tags, { Name = "${var.project}-${var.environment}-eks-nodes-sg" })
}

resource "aws_security_group_rule" "cluster_from_nodes" {
  description              = "Allow nodes to reach the control plane"
  type                     = "ingress"
  from_port                = 443; to_port = 443; protocol = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_cluster.id
}

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Internet-facing ALB security group"
  vpc_id      = aws_vpc.main.id
  ingress { from_port = 80;  to_port = 80;  protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; description = "HTTP from internet" }
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; description = "HTTPS from internet" }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = [var.vpc_cidr]; description = "Outbound to VPC" }
  tags        = merge(local.tags, { Name = "${var.project}-${var.environment}-alb-sg" })
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpc/${var.project}-${var.environment}"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_iam_role" "vpc_flow" {
  name = "${var.project}-${var.environment}-vpc-flow-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Principal = { Service = "vpc-flow-logs.amazonaws.com" }; Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "vpc_flow" {
  name = "cloudwatch-logs"
  role = aws_iam_role.vpc_flow.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogGroups","logs:DescribeLogStreams"]; Resource = "*" }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow.arn
  tags            = local.tags
}
