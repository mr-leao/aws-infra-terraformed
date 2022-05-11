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
    format("%s/central-log-archive/ca-central-1/log-archive", "${get_parent_terragrunt_dir()}"),
    "../vpc-internet-egress"
  ]
}

dependency "transit_gateway" {
  config_path = "../transit-gateway"
  mock_outputs = {
    main_transit_gateway_id          = "tgw-111111111111"
    main_tgw_egress_route_table_id   = "tgw-rtb-egress"
    main_tgw_internal_route_table_id = "tgw-rtb-internal"
  }
}

dependency "vpc_internet_egress" {
  config_path = "../vpc-internet-egress"
  mock_outputs = {
    public_route_table_id             = "rtb-111111111111"
    transit_gateway_vpc_attachment_id = "tgw-at-1111111111111111"
  }
}

#Fake dependency
dependency "vpc_core" {
  config_path = "../vpc-internet-egress"
  mock_outputs = {
    transit_gateway_vpc_attachment_id = "tgw-at-1111111111111111"
  }
}

inputs = {
  is_networkhub_vpc           = true
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