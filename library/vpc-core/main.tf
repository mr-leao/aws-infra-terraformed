### The modulo is used only for private VPC configuration
### Internet egress connectivity is provided through the network hub account via NAT Gateway

locals {
  subnet_config = { for config in var.subnetting_config : "${var.vpc_name}-${config.route}-${config.az_type}" => config if config.route == "private" }
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
  alias               = "nethub"
  profile             = var.aws_local_profile
  region              = var.region
  allowed_account_ids = var.aws_allowed_account_ids
  assume_role {
    role_arn = "arn:aws:iam::${var.main_network_hub_account_id}:role/${var.deployment_service_iam_role_name}"
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

#The ec2 key pair must be created manually. This is a requirement before executing Terraform deployments
# Check the readme.md file for more details
data "aws_key_pair" "vpc" {
  key_name = var.keypair_name
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = "true"
  enable_dns_hostnames = "true" # Enable public DNS hostnames for Public IP addresses - Required for VPC Endpoints.
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = var.vpc_name
    }
  )
}

## DHCP Options
# To be implemented

# Network ACLs
# To be implemented

# Common security groups
# To be implemented

#Blank out the default security group. You can't delete it so removing all rules secures it in the event of accidental use.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "default" {
  name        = "My Default"
  description = "My Default Rule"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "all"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_flow_log" "vpc_s3" {
  log_destination      = var.log_archive_outputs.all_flowlogs_s3_bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.vpc.id
  destination_options {
    file_format                = "plain-text"
    hive_compatible_partitions = false
    per_hour_partition         = false
  }
  tags = merge(
    var.global_tags, var.deployment_tags
  )
}

## Subnets
# Needs review. Picking AZs from data source is safer that assigning the postfixes "a", and "b" at the end of a string.
# Some region might have different letters

# data "aws_availability_zones" "available" {
#   state = "available"
# }
# resource "random_shuffle" "az" {
#   input        = data.aws_availability_zones.available.names
#   result_count = 2
#   count = 2
# }

# resource "random_integer" "az_list_index" {
#   min = 0
#   max = 1
# }

resource "aws_subnet" "subnets" {
  for_each          = local.subnet_config
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, each.value.newbits, each.value.netnum)
  availability_zone = "${var.region}${each.value.az_postfix}"
  #availability_zone = random_shuffle.az.result[tonumber(random_integer.az_list_index.result)]
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name}-${each.value.route}-${each.value.az_type}"
    }
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  subnet_ids         = [for k, v in local.subnet_ids : v]
  transit_gateway_id = var.transit_gateway_outputs.main_transit_gateway_id
  vpc_id             = aws_vpc.vpc.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - VPC Core Attachment"
    }
  )
}

# resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "vpc_core" {
#   provider = aws.nethub
#   transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.main.id
#   tags = merge(
#     var.global_tags, var.deployment_tags,
#     { Name = "${var.vpc_name} - VPC Core Attachment Accepter"
#     }
#   )
# }

## Routing tables
resource "aws_route_table" "private_primary" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - Private Primary"
    }
  )
}

resource "aws_route" "private_primary" {
  route_table_id         = aws_route_table.private_primary.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_outputs.main_transit_gateway_id
}

resource "aws_route_table" "private_secondary" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - Private Secondary"
    }
  )
}

resource "aws_route" "private_secondary" {
  route_table_id         = aws_route_table.private_secondary.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_outputs.main_transit_gateway_id
}
locals {
  subnet_ids = { for config in var.subnetting_config : "${var.vpc_name}-${config.route}-${config.az_type}" => aws_subnet.subnets["${var.vpc_name}-${config.route}-${config.az_type}"].id if config.route == "private" }
}

resource "aws_route_table_association" "private_primary" {
  subnet_id      = local.subnet_ids["${var.vpc_name}-private-primary"]
  route_table_id = aws_route_table.private_primary.id
}

resource "aws_route_table_association" "private_secondary" {
  subnet_id      = local.subnet_ids["${var.vpc_name}-private-secondary"]
  route_table_id = aws_route_table.private_secondary.id
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc_association" {
  provider                       = aws.nethub
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_internal_route_table_id
}

resource "aws_ec2_transit_gateway_route" "egress" {
  provider                       = aws.nethub
  destination_cidr_block         = var.vpc_cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_egress_route_table_id
}

# resource "aws_ec2_transit_gateway_route" "default" {
#   provider = aws.nethub
#   destination_cidr_block         = "0.0.0.0/0"
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
#   transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_internal_route_table_id
# }

# Domain Name Configuration
resource "aws_route53_zone" "hosted_private_zone" {
  count = try(var.domain_names["private"][var.vpc_name] != "" ? 1 : 0, 0)
  name  = var.domain_names["private"][var.vpc_name]

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name} - hosted zone"
    }
  )
}

# The following block of code can be use if there is a need to resolve cross account names
# https://aws.amazon.com/blogs/security/simplify-dns-management-in-a-multiaccount-environment-with-route-53-resolver/
# resource "aws_route53_resolver_endpoint" "outbound" {
#   count = var.is_networkhub_vpc ? 1: 0
#   name      = "${var.vpc_name} - outbound"
#   direction = "OUTBOUND"

#   security_group_ids = [
#     aws_default_security_group.default.id
#   ]

#   ip_address {
#     subnet_id = aws_subnet.subnets["${var.vpc_name}-private-primary"].id
#   }

#   ip_address {
#     subnet_id = aws_subnet.subnets["${var.vpc_name}-private-secondary"].id
#     #ip        = "???" need to figure out how to find the subnet`s cidr and calculate an ip address
#   }

#   tags = merge(
#     var.global_tags, var.deployment_tags,
#     {
#       Name = "${var.vpc_name} - Outbound domain name resolver"
#     }
#   ) 
# }

# resource "aws_route53_resolver_rule" "outbound_forward" {}
# resource "aws_route53_resolver_rule" "inbound" {}
# resource "aws_route53_resolver_rule" "inbound_forward" {}

