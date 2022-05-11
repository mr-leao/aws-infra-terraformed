terraform {
  # Intentionally empty. Will be filled by Terragrunt.
  backend "s3" {}
  required_version = "= 1.1.6"
  required_providers {
    aws = "= 4.10.0"
  }
}

provider "aws" {
  profile             = var.aws_local_profile
  region              = var.region
  allowed_account_ids = var.aws_allowed_account_ids
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.deployment_service_iam_role_name}"
  }
}
#AWS-managed and Customer-managed KMS Keys
#https://docs.aws.amazon.com/whitepapers/latest/kms-best-practices/aws-managed-and-customer-managed-cmks.html
resource "aws_kms_key" "serverless_artifacts" {
  description = "S3BucketServerlessArtifact"
}
resource "aws_s3_bucket" "serverless_artifacts" {
  bucket = "${var.vpc_name}-${var.account_id}-${var.region}-serverless-artifacts"
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name}-${var.account_id}-${var.region}-serverless-artifacts"
    }
  )
}
resource "aws_s3_bucket_server_side_encryption_configuration" "serverless_artifacts" {
  bucket = aws_s3_bucket.serverless_artifacts.bucket
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.serverless_artifacts.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "all_flowlogs" {
  bucket = aws_s3_bucket.serverless_artifacts.bucket

  rule {
    id = "Transition and Expiration Rule"

    expiration {
      days = 365 #For POC purpose it is set to 1 years, but we need to check the local regulations
    }

    filter {}

    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA" #Standard-Infrequent Access
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "vpc_flow_log" {
  bucket                  = aws_s3_bucket.serverless_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}