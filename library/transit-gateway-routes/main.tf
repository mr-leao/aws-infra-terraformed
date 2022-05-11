###  ###
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
    role_arn = "arn:aws:iam::${var.main_network_hub_account_id}:role/${var.deployment_service_iam_role_name}"
  }
}

# Problem to be solved

# Error: error associating EC2 Transit Gateway Route Table (tgw-rtb-xxxxxxxxxxxxx) association (tgw-attach-xxxxxxxxxxxxx): Resource.AlreadyAssociated: Transit Gateway Attachment tgw-attach-xxxxxxxxxxxxx is already associated to a route table.
# 	status code: 400, request id: ........

#https://github.com/hashicorp/terraform-provider-aws/issues/16452
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment_accepter
#https://github.com/hashicorp/terraform-provider-aws/blob/main/examples/transit-gateway-cross-account-vpc-attachment/main.tf


# resource "aws_ec2_transit_gateway_route_table_association" "vpc_association" {
#   transit_gateway_attachment_id  = var.is_networkhub_vpc ? var.vpc_internet_egress_outputs.transit_gateway_vpc_attachment_id : var.vpc_outputs.transit_gateway_vpc_attachment_id
#   transit_gateway_route_table_id = var.is_networkhub_vpc ? var.transit_gateway_outputs.main_tgw_egress_route_table_id : var.transit_gateway_outputs.main_tgw_internal_route_table_id
# }

#Egress Route

# resource "aws_ec2_transit_gateway_route" "egress" {
#   count                          = var.is_networkhub_vpc ? 0 : 1
#   destination_cidr_block         = var.vpc_outputs.vpc_cidr_block
#   transit_gateway_attachment_id  = var.vpc_outputs.transit_gateway_vpc_attachment_id
#   transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_egress_route_table_id
# }

#Ingress TGW Route

resource "aws_ec2_transit_gateway_route" "default" {
  count                          = var.is_networkhub_vpc ? 1 : 0
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = var.vpc_outputs.transit_gateway_vpc_attachment_id
  transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_internal_route_table_id
}

#Blackhole to make sure VPCs can’t communicate with each other through the NAT gateway
resource "aws_ec2_transit_gateway_route" "blackhole192" {
  count                          = var.is_networkhub_vpc ? 1 : 0
  destination_cidr_block         = "192.168.0.0/16"
  transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_internal_route_table_id
  blackhole                      = true
}

resource "aws_ec2_transit_gateway_route" "blackhole172" {
  count                          = var.is_networkhub_vpc ? 1 : 0
  destination_cidr_block         = "172.16.0.0/12"
  transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_internal_route_table_id
  blackhole                      = true
}

resource "aws_ec2_transit_gateway_route" "blackhole10" {
  count                          = var.is_networkhub_vpc ? 1 : 0
  destination_cidr_block         = "10.0.0.0/8"
  transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_internal_route_table_id
  blackhole                      = true
}

resource "aws_route" "public" {
  count                  = var.is_networkhub_vpc ? 0 : 1
  route_table_id         = var.vpc_internet_egress_outputs.public_route_table_id
  destination_cidr_block = var.vpc_outputs.vpc_cidr_block
  transit_gateway_id     = var.transit_gateway_outputs.main_transit_gateway_id
}