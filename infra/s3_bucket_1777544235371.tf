
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "image_bucket" {
  bucket = "ssd-aide-test-apr30"

  tags = {
    Name    = "ssd-aide-test-apr30"
    Purpose = "Image Storage"
  }
}

resource "aws_s3_bucket_ownership_controls" "image_bucket_ownership" {
  bucket = aws_s3_bucket.image_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "image_bucket_public_access" {
  bucket = aws_s3_bucket.image_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
