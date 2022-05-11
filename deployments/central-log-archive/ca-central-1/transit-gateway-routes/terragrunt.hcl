locals {
  deployment_vars = yamldecode(file("${get_terragrunt_dir()}/../../deployment.yml"))
  region_vars     = yamldecode(file("${get_terragrunt_dir()}/../region.yml"))
  vars            = merge(local.deployment_vars, local.region_vars)
  deployment      = "${local.vars.deployment_prefix}${local.vars.vpc_cidr_2nd_octet}"
}

include {
  path = find_in_parent_folders("global.hcl")
}

terraform {
  source = format("%s/../library//transit-gateway-routes", "${get_parent_terragrunt_dir()}")
}

dependencies {
  paths = [
    "../vpc-core"
  ]
}

dependency "transit_gateway" {
  config_path = format("%s/network-hub/ca-central-1/transit-gateway", "${get_parent_terragrunt_dir()}")
  mock_outputs = {
    main_transit_gateway_id          = "tgw-111111111111"
    main_tgw_egress_route_table_id   = "tgw-rtb-egress"
    main_tgw_internal_route_table_id = "tgw-rtb-internal"
  }
}

dependency "vpc_internet_egress" {
  config_path = format("%s/network-hub/ca-central-1/vpc-internet-egress", "${get_parent_terragrunt_dir()}")
  mock_outputs = {
    public_route_table_id             = "rtb-111111111111"
    transit_gateway_vpc_attachment_id = "tgw-at-1111111111111111"
  }
}

dependency "vpc_core" {
  config_path = "../vpc-core"
  mock_outputs = {
    transit_gateway_vpc_attachment_id = "tgw-at-1111111111111111"
    vpc_cidr_block                    = "10.0.0.0/16"
  }
}

inputs = {
  is_networkhub_vpc           = false
  account_id                  = local.vars.account_id
  region                      = local.vars.region
  environment                 = local.vars.environment
  vpc_name                    = local.deployment
  transit_gateway_outputs     = dependency.transit_gateway.outputs
  vpc_internet_egress_outputs = dependency.vpc_internet_egress.outputs
  vpc_outputs                 = dependency.vpc_core.outputs
  deployment_tags = {
    env        = local.vars.environment
    deployment = local.deployment
  }
  endpoint_list_interface = []
  endpoint_list_gateway   = []
}