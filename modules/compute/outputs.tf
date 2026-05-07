output "cluster_name"          { description = "EKS cluster name"; value = aws_eks_cluster.main.name }
output "cluster_endpoint"      { description = "EKS API server endpoint"; value = aws_eks_cluster.main.endpoint }
output "cluster_arn"           { description = "EKS cluster ARN"; value = aws_eks_cluster.main.arn }
output "cluster_ca_data"       { description = "Base64 encoded cluster CA certificate"; value = aws_eks_cluster.main.certificate_authority[0].data }
output "alb_controller_role_arn" { description = "IAM role ARN for the AWS Load Balancer Controller"; value = aws_iam_role.alb_controller.arn }
output "node_group_role_arn"   { description = "IAM role ARN for node groups"; value = aws_iam_role.nodes.arn }
