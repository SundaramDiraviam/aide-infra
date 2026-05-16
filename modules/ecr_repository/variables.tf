
variable "aws_region" {
  description = "AWS region where the ECR repository will be created."
  type        = string
  default     = "us-east-1"
}

variable "repository_name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "project" {
  description = "Project name used for tagging and resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repository. Must be MUTABLE or IMMUTABLE."
  type        = string
  default     = "IMMUTABLE"
}

variable "force_delete" {
  description = "If true, the repository is deleted even if it contains images."
  type        = bool
  default     = false
}

variable "kms_deletion_window_days" {
  description = "Number of days before the KMS key is deleted after being scheduled for deletion (7 to 30)."
  type        = number
  default     = 30
}

variable "max_image_count" {
  description = "Maximum number of tagged images to retain. Images beyond this count are expired."
  type        = number
  default     = 10
}

variable "lifecycle_tag_prefixes" {
  description = "List of image tag prefixes that the lifecycle retention rule applies to."
  type        = list(string)
  default     = ["v"]
}

variable "untagged_expiry_days" {
  description = "Number of days after which untagged images are expired."
  type        = number
  default     = 7
}

variable "allowed_pull_principals" {
  description = "List of IAM principal ARNs (roles or accounts) allowed to pull images. Leave empty to skip the repository policy."
  type        = list(string)
  default     = []
}
