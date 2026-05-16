# module: ecr_repository

ECR repository with scan-on-push, KMS encryption, and a lifecycle policy retaining the last 10 images

## Usage

```hcl
module "ecr_repository" {
  source = "git::https://github.com/SundaramDiraviam/aide-infra.git//modules/ecr_repository?ref=main"
  # pass required variables
}
```

## Inputs

See `variables.tf` for all inputs with descriptions and types.

## Outputs

See `outputs.tf` for all outputs.
