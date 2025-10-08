# Build bucket name with random suffix
resource "random_id" "suffix" {
  byte_length = 4
}
locals {
  bucket_name = "tfstate-${random_id.suffix.hex}"
}

# Create the S3 bucket for remote state
resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "v" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


resource "aws_s3_bucket_public_access_block" "pab" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Output the generated bucket name
output "bucket_name" {
  value       = aws_s3_bucket.state.bucket
  description = "S3 bucket name for Terraform state"
}


output "backend_config" {
  value = {
    bucket = aws_s3_bucket.state.bucket
    key    = "foundation/terraform.tfstate"
    region = var.aws_region
  }
  description = "Backend configuration for use in other Terraform projects"
}
