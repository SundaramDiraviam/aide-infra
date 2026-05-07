output "ecr_kms_key_arn" { description = "KMS key ARN for ECR encryption"; value = aws_kms_key.ecr.arn }
output "s3_kms_key_arn"  { description = "KMS key ARN for S3 encryption"; value = aws_kms_key.s3.arn }
output "artifacts_bucket" { description = "S3 artifact bucket name"; value = aws_s3_bucket.artifacts.id }
output "ecr_aide_demo_home_url" { description = "ECR URL for aide-demo-home"; value = aws_ecr_repository.aide_demo_home.repository_url }
output "ecr_aide_demo_platform_url" { description = "ECR URL for aide-demo-platform"; value = aws_ecr_repository.aide_demo_platform.repository_url }
output "ecr_aide_demo_status_url" { description = "ECR URL for aide-demo-status"; value = aws_ecr_repository.aide_demo_status.repository_url }
