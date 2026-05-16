
output "repository_name" {
  description = "Name of the ECR repository."
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "Full URI of the ECR repository (used in docker push/pull commands)."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.this.arn
}

output "registry_id" {
  description = "Registry ID (AWS account ID) that owns the repository."
  value       = aws_ecr_repository.this.registry_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt ECR images."
  value       = aws_kms_key.ecr.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key used to encrypt ECR images."
  value       = aws_kms_alias.ecr.name
}
