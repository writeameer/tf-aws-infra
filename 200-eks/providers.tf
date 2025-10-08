provider "aws" {
  region = data.terraform_remote_state.foundation.outputs.aws_region

  default_tags {
    tags = {
      Project     = "EKS Demo"
      Environment = data.terraform_remote_state.foundation.outputs.environment
      ManagedBy   = "Terraform"
      Module      = "02-eks"
    }
  }
}