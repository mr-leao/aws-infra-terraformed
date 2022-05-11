locals {
  flowLogAccounts = [for account_id in var.aws_allowed_account_ids : "arn:aws:logs:*:${account_id}:*"]
}

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

resource "aws_s3_bucket" "all_flowlogs" {
  bucket = "${var.vpc_name}-${var.account_id}-${var.region}-all-flowlogs"
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name}-all-flowLogs"
    }
  )
}

# With KMS key enabled in the Central Log Archive account, the delivery log service (delivery.logs.amazonaws.com) from other accounts is unable to configure FlowLogs for its VPC.
# We need to figure out what KMS policies are required to allow the delivery service to configure and write log into the S3 bucket
#The following error occurs: "#400: Access Denied for LogDestination: %bucket-name%. Please check LogDestination permission".

# resource "aws_kms_key" "all_flowlogs" {
#   description = "FlowLogs"
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "all_flowlogs" {
#   bucket = aws_s3_bucket.all_flowlogs.bucket

#   rule {
#     apply_server_side_encryption_by_default {
#       kms_master_key_id = aws_kms_key.all_flowlogs.arn
#       sse_algorithm     = "aws:kms"
#     }
#   }
# }
resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.all_flowlogs.id

  # Objects uploaded to the bucket change ownership to the bucket owner if the objects are uploaded with the bucket-owner-full-control canned ACL.
  # https://aws.amazon.com/premiumsupport/knowledge-center/s3-bucket-owner-full-control-acl/
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "all_flowlogs" {
  bucket                  = aws_s3_bucket.all_flowlogs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "all_flowlogs" {
  bucket = aws_s3_bucket.all_flowlogs.bucket

  rule {
    id = "Transition and Expiration Rule"

    expiration {
      days = 1095 #For POC purpose it is set to 3 years, but we need to check the local regulations
    }

    filter {}

    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA" #Standard-Infrequent Access
    }

    transition {
      days          = 60
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

resource "aws_s3_bucket_policy" "all_flowlogs" {
  bucket = aws_s3_bucket.all_flowlogs.id
  policy = data.aws_iam_policy_document.all_flowlogs.json
}

# #Policy to grant other account access to write FlowLogs
data "aws_iam_policy_document" "all_flowlogs" {

  statement {

    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = [aws_s3_bucket.all_flowlogs.arn, "${aws_s3_bucket.all_flowlogs.arn}/*"]

    # Uploads can be performed only when the object's ACL is set to "bucket-owner-full-control".
    # So When the bucket-owner-full-control ACL is added, the bucket owner has full control over any new objects that are written by other accounts
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.aws_allowed_account_ids
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = local.flowLogAccounts
    }

  }

  statement {
    sid    = "AWSLogDeliveryCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [aws_s3_bucket.all_flowlogs.arn, "${aws_s3_bucket.all_flowlogs.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = var.aws_allowed_account_ids
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = local.flowLogAccounts
    }
  }
  #Related to the "Access Denied for LogDestination / KMS" issue
  # statement {
  #   sid    = "KMSAccess"
  #   effect = "Allow"
  #   principals {
  #     type        = "Service"
  #     identifiers = ["delivery.logs.amazonaws.com"]
  #   }
  #   actions = [
  #     "kms:ReEncrypt",
  #     "kms:GenerateDataKey",
  #     "kms:Encrypt",
  #     "kms:DescribeKey",
  #     "kms:Decrypt"
  #   ]
  #   resources = [aws_kms_key.all_flowlogs.arn]

  # }
}

