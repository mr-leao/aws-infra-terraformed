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
resource "aws_ssm_parameter" "subnet_ids" {
  name  = "/${var.vpc_core_outputs.vpc_name}/vpc/subnets"
  type  = "String"
  value = jsonencode(var.vpc_core_outputs.subnet_ids)
}
# resource "aws_ssm_parameter" "subnet_id_private_primary" {
#   name  = "/${var.vpc_core_outputs.vpc_name}/vpc/subnets/private/primary"
#   type  = "String"
#   value = var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-primary"]
# }

# resource "aws_ssm_parameter" "subnet_id_private_secondary" {
#   name  = "/${var.vpc_core_outputs.vpc_name}/vpc/subnets/private/secondary"
#   type  = "String"
#   value = var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-private-secondary"]
# }

# resource "aws_ssm_parameter" "subnet_id_public_primary" {
#   name  = "/${var.vpc_core_outputs.vpc_name}/vpc/subnets/public/primary"
#   type  = "String"
#   value = var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-public-primary"]
# }

# resource "aws_ssm_parameter" "subnet_id_public_secondary" {
#   name  = "/${var.vpc_core_outputs.vpc_name}/vpc/subnets/public/secondary"
#   type  = "String"
#   value = var.vpc_core_outputs.subnet_ids["${var.vpc_core_outputs.vpc_name}-public-secondary"]
# }

resource "aws_ssm_parameter" "s3_serverless_artifacts_bucket" {
  name  = "/${var.vpc_core_outputs.vpc_name}/serverless/artifacts-s3-bucket"
  type  = "String"
  value = var.serverless_framework_outputs.serverless_artifacts_bucket_id
}

