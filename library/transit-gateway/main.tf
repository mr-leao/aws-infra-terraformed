### Only use this module with the Networking Hub account ###
terraform {
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

resource "aws_ec2_transit_gateway" "main" {
  description                    = "${var.vpc_name}-main"
  auto_accept_shared_attachments = "enable"
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name}-main"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "main_tgw_egress" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - Main Egress Table"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "main_tgw_internal" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - Main Internal Table"
    }
  )
}

data "aws_organizations_organization" "my_org" {}

resource "aws_ram_resource_share" "twg-main" {
  name                      = "Transit-Gateway-Main"
  allow_external_principals = false
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name}-main"
    }
  )
}

resource "aws_ram_resource_association" "twg-main" {
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.twg-main.arn
}


resource "aws_ram_principal_association" "twg-main" {
  principal          = data.aws_organizations_organization.my_org.arn
  resource_share_arn = aws_ram_resource_share.twg-main.arn
}