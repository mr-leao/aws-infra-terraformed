include {
  path = find_in_parent_folders("global.hcl")
}

terraform {
  source = format("%s/../library//vpc-core", "${get_parent_terragrunt_dir()}")
}

dependencies {
  paths = [format("%s/central-log-archive/ca-central-1/log-archive", "${get_parent_terragrunt_dir()}"), format("%s/network-hub/ca-central-1/transit-gateway", "${get_parent_terragrunt_dir()}")]
}

dependency "log_archive" {
  config_path = format("%s/central-log-archive/ca-central-1/log-archive", "${get_parent_terragrunt_dir()}")
  mock_outputs = {
    all_flowlogs_s3_bucket_arn = "arn:aws:s3:::mocked_output"
  }
}

dependency "transit_gateway" {
  config_path = format("%s/network-hub/ca-central-1/transit-gateway", "${get_parent_terragrunt_dir()}")
  mock_outputs = {
    main_transit_gateway_id        = "tgw-111111111111"
    main_tgw_egress_route_table_id = "tgw-rtb-111111111111"
  }
}

locals {
  deployment_vars = yamldecode(file("${get_terragrunt_dir()}/../../deployment.yml"))
  region_vars     = yamldecode(file("${get_terragrunt_dir()}/../region.yml"))
  vars            = merge(local.deployment_vars, local.region_vars)
  deployment      = "${local.vars.deployment_prefix}${local.vars.vpc_cidr_2nd_octet}"
}

inputs = {
  is_networkhub_vpc          = false
  keypair_name               = "${local.vars.deployment_prefix}${local.vars.vpc_cidr_2nd_octet}-${local.vars.region}"
  account_id                 = local.vars.account_id
  region                     = local.vars.region
  environment                = local.vars.environment
  vpc_name                   = local.deployment
  vpc_cidr_block             = "${local.vars.vpc_cidr_1st_octet}.${local.vars.vpc_cidr_2nd_octet}.0.0/16"
  all_flowlogs_s3_bucket_arn = dependency.log_archive.outputs.all_flowlogs_s3_bucket_arn
  transit_gateway_outputs    = dependency.transit_gateway.outputs
  deployment_tags = {
    env        = local.vars.environment
    deployment = local.deployment
  }
  endpoint_list_interface = []
  endpoint_list_gateway   = []

  # To be using with the terraform function "cidrsubnet(prefix, newbits, netnum)"
  # https://www.terraform.io/language/functions/cidrsubnet
  # Need to findout how to move the subnets list to a top-level config file to avoid copy-and-past it whenever a new vpc-core is implemented

  subnetting_config = [
    {
      az_type    = "primary"
      az_postfix = "a"
      newbits    = "8"
      netnum     = "0"
      route      = "private"
      nacl       = "private"
    },
    {
      az_type    = "secondary"
      az_postfix = "b"
      newbits    = "8"
      netnum     = "1"
      route      = "private"
      nacl       = "private"
    }
  ]
}