locals {
  merged_endpoint_list_interface = concat(var.common_endpoint_list_interface, var.endpoint_list_interface)
  merged_endpoint_list_gateway   = concat(var.common_endpoint_list_gateway, var.endpoint_list_gateway)
  mapped_endpoint_list_interface = { for endpoint in local.merged_endpoint_list_interface : "${var.vpc_name}_${endpoint.service_name}" => endpoint }
  mapped_endpoint_list_gateway   = { for endpoint in local.merged_endpoint_list_gateway : "${var.vpc_name}_${endpoint.service_name}" => endpoint }
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

resource "aws_vpc_endpoint" "endpoint_interface" {
  for_each          = local.mapped_endpoint_list_interface
  vpc_id            = var.vpc_outputs.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value.service_name}"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    var.vpc_outputs.my_security_group_id #"sg-0a4b3fc5e752fcb77"
    #var.my_security_group_id
  ]

  private_dns_enabled = true
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name} - ${each.value.name}"
    }
  )
}

locals {
  endpoint_interface_map_name_id = { for endpoint in local.merged_endpoint_list_interface : "${var.vpc_name}_${endpoint.service_name}" => aws_vpc_endpoint.endpoint_interface["${var.vpc_name}_${endpoint.service_name}"].id }
}

# # Endpoints don't get associated to subnets automatically it has be done.
resource "aws_vpc_endpoint_subnet_association" "endpoint_subnet" {
  for_each        = local.mapped_endpoint_list_interface
  vpc_endpoint_id = local.endpoint_interface_map_name_id["${var.vpc_name}_${each.value.service_name}"]
  subnet_id       = var.vpc_outputs.subnet_ids["${var.vpc_outputs.vpc_name}-private-primary"]
}

### Endpoint Gateway for services such as S3 which are routes
resource "aws_vpc_endpoint" "endpoint_gateway" {
  for_each          = local.mapped_endpoint_list_gateway
  vpc_id            = var.vpc_outputs.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value.service_name}"
  vpc_endpoint_type = "Gateway"

  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name} - ${each.value.name}"
    }
  )
}

locals {
  endpoint_gateway_map_name_id = { for endpoint in local.merged_endpoint_list_gateway : "${var.vpc_name}_${endpoint.service_name}" => aws_vpc_endpoint.endpoint_gateway["${var.vpc_name}_${endpoint.service_name}"].id }
  endpoint_gateway_prefix_list = { for endpoint in local.merged_endpoint_list_gateway : "${var.vpc_name}_${endpoint.service_name}" => aws_vpc_endpoint.endpoint_gateway["${var.vpc_name}_${endpoint.service_name}"].prefix_list_id }
}
# Gateway endpoints are routs, so we need to update the routing tables of subnets that need acces.
# resource "aws_vpc_endpoint_route_table_association" "endpoint_gateway_table_public" {
#   for_each        = local.mapped_endpoint_list_gateway
#   route_table_id  = var.vpc_outputs.public_route_table_id
#   vpc_endpoint_id = local.endpoint_gateway_map_name_id["${var.vpc_name}_${each.value.service_name}"]
# }
resource "aws_vpc_endpoint_route_table_association" "endpoint_gateway_table_private" {
  for_each        = local.mapped_endpoint_list_gateway
  route_table_id  = var.vpc_outputs.private_primary_route_table_id
  vpc_endpoint_id = local.endpoint_gateway_map_name_id["${var.vpc_name}_${each.value.service_name}"]
}
