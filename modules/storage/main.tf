# Storage module: KMS keys, ECR repositories with scanning and lifecycle policies, S3 artifact bucket.

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

locals {
  tags = { Project = var.project; Environment = var.environment; ManagedBy = "terraform" }
}

resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(local.tags, { Name = "${var.project}-${var.environment}-ecr-kms" })
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 artifact bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(local.tags, { Name = "${var.project}-${var.environment}-s3-kms" })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project}-${var.environment}-s3"
  target_key_id = aws_kms_key.s3.key_id
}


resource "aws_ecr_repository" "aide_demo_home" {
  name                 = "${var.project}-${var.environment}-aide-demo-home"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS"; kms_key = aws_kms_key.ecr.arn }
  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-aide-demo-home" })
}

resource "aws_ecr_lifecycle_policy" "aide_demo_home" {
  repository = aws_ecr_repository.aide_demo_home.name
  policy = jsonencode({ rules = [
    { rulePriority = 1; description = "Expire untagged after 7 days"; selection = { tagStatus = "untagged"; countType = "sinceImagePushed"; countUnit = "days"; countNumber = 7 }; action = { type = "expire" } },
    { rulePriority = 2; description = "Keep last 10 tagged images"; selection = { tagStatus = "tagged"; tagPrefixList = ["sha-","v"]; countType = "imageCountMoreThan"; countNumber = 10 }; action = { type = "expire" } }
  ]})
}

resource "aws_ecr_repository" "aide_demo_platform" {
  name                 = "${var.project}-${var.environment}-aide-demo-platform"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS"; kms_key = aws_kms_key.ecr.arn }
  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-aide-demo-platform" })
}

resource "aws_ecr_lifecycle_policy" "aide_demo_platform" {
  repository = aws_ecr_repository.aide_demo_platform.name
  policy = jsonencode({ rules = [
    { rulePriority = 1; description = "Expire untagged after 7 days"; selection = { tagStatus = "untagged"; countType = "sinceImagePushed"; countUnit = "days"; countNumber = 7 }; action = { type = "expire" } },
    { rulePriority = 2; description = "Keep last 10 tagged images"; selection = { tagStatus = "tagged"; tagPrefixList = ["sha-","v"]; countType = "imageCountMoreThan"; countNumber = 10 }; action = { type = "expire" } }
  ]})
}

resource "aws_ecr_repository" "aide_demo_status" {
  name                 = "${var.project}-${var.environment}-aide-demo-status"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "KMS"; kms_key = aws_kms_key.ecr.arn }
  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-aide-demo-status" })
}

resource "aws_ecr_lifecycle_policy" "aide_demo_status" {
  repository = aws_ecr_repository.aide_demo_status.name
  policy = jsonencode({ rules = [
    { rulePriority = 1; description = "Expire untagged after 7 days"; selection = { tagStatus = "untagged"; countType = "sinceImagePushed"; countUnit = "days"; countNumber = 7 }; action = { type = "expire" } },
    { rulePriority = 2; description = "Keep last 10 tagged images"; selection = { tagStatus = "tagged"; tagPrefixList = ["sha-","v"]; countType = "imageCountMoreThan"; countNumber = 10 }; action = { type = "expire" } }
  ]})
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project}-${var.environment}-artifacts-${var.aws_region}"
  force_destroy = var.environment != "prod"
  tags          = merge(local.tags, { Name = "${var.project}-${var.environment}-artifacts" })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms"; kms_master_key_id = aws_kms_key.s3.arn }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
