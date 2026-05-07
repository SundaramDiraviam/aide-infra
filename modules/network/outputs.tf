output "vpc_id"             { description = "VPC ID"; value = aws_vpc.main.id }
output "public_subnet_ids"  { description = "Public subnet IDs (one per AZ)"; value = aws_subnet.public[*].id }
output "private_subnet_ids" { description = "Private subnet IDs for EKS nodes"; value = aws_subnet.private[*].id }
output "eks_cluster_sg_id"  { description = "EKS control plane security group ID"; value = aws_security_group.eks_cluster.id }
output "eks_nodes_sg_id"    { description = "EKS node group security group ID"; value = aws_security_group.eks_nodes.id }
output "alb_sg_id"          { description = "Internet-facing ALB security group ID"; value = aws_security_group.alb.id }
output "nat_gateway_ip"     { description = "Public IP of the NAT Gateway"; value = aws_eip.nat.public_ip }
