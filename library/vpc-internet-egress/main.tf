### Only use this module with the Networking Hub account ###

locals {
  public_subnets_config  = { for config in var.subnetting_config : "${var.vpc_name}-${config.route}-${config.az_type}" => config if config.route == "public" }
  private_subnets_config = { for config in var.subnetting_config : "${var.vpc_name}-${config.route}-${config.az_type}" => config if config.route == "private" }
  subnet_config          = var.is_networkhub_vpc == 0 ? local.private_subnets_config : merge(local.public_subnets_config, local.private_subnets_config)
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

resource "aws_internet_gateway" "vpc_internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = var.vpc_name
    }
  )
}

resource "aws_eip" "primary" {
  vpc = true
}

resource "aws_eip" "secondary" {
  vpc = true
}

locals {
  public_subnet_ids  = { for config in var.subnetting_config : "${var.vpc_name}-${config.route}-${config.az_type}" => aws_subnet.subnets["${var.vpc_name}-${config.route}-${config.az_type}"].id if config.route == "public" }
  private_subnet_ids = { for config in var.subnetting_config : "${var.vpc_name}-${config.route}-${config.az_type}" => aws_subnet.subnets["${var.vpc_name}-${config.route}-${config.az_type}"].id if config.route == "private" }
  subnet_ids         = var.is_networkhub_vpc ? merge(local.public_subnet_ids, local.private_subnet_ids) : local.private_subnet_ids
}

resource "aws_nat_gateway" "public_primary" {
  allocation_id = aws_eip.primary.id
  subnet_id     = local.public_subnet_ids["${var.vpc_name}-public-primary"]
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name} - Public Primary NAT Gateway"
    }
  )
  depends_on = [aws_internet_gateway.vpc_internet_gateway]
}

resource "aws_nat_gateway" "public_secondary" {
  allocation_id = aws_eip.secondary.id
  subnet_id     = local.public_subnet_ids["${var.vpc_name}-public-secondary"]
  tags = merge(
    var.global_tags, var.deployment_tags,
    {
      Name = "${var.vpc_name} - Public Secondary NAT Gateway"
    }
  )
  depends_on = [aws_internet_gateway.vpc_internet_gateway]
}

## Routing tables

# Public route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - Public Routing Table"
    }
  )
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc_internet_gateway.id
}

# Private route
resource "aws_route_table" "private_primary" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - Private Primary Routing Table"
    }
  )
}

resource "aws_route" "private_primary" {
  route_table_id         = aws_route_table.private_primary.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public_primary.id
}

resource "aws_route_table" "private_secondary" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - Private Secondary Routing Table"
    }
  )
}

resource "aws_route" "private_secondary" {
  route_table_id         = aws_route_table.private_secondary.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public_secondary.id
}

#Using one route table for both public subnet since the point to the same internet gateway
resource "aws_route_table_association" "public" {
  for_each       = { for k, v in local.public_subnets_config : k => v }
  subnet_id      = local.subnet_ids["${var.vpc_name}-${each.value.route}-${each.value.az_type}"]
  route_table_id = aws_route_table.public.id
}

#Using separate route table for private subnets since they point to different NAT Gateways
resource "aws_route_table_association" "private_primary" {
  subnet_id      = local.subnet_ids["${var.vpc_name}-private-primary"]
  route_table_id = aws_route_table.private_primary.id
}

resource "aws_route_table_association" "private_secondary" {
  subnet_id      = local.subnet_ids["${var.vpc_name}-private-secondary"]
  route_table_id = aws_route_table.private_secondary.id
}

#Private Egress Subnets attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "egress_vpc" {
  subnet_ids                                      = [for k, v in local.private_subnet_ids : v]
  transit_gateway_id                              = var.transit_gateway_outputs.main_transit_gateway_id
  vpc_id                                          = aws_vpc.vpc.id
  transit_gateway_default_route_table_association = false
  tags = merge(
    var.global_tags, var.deployment_tags,
    { Name = "${var.vpc_name} - VPC Egress Attachment"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "vpc_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress_vpc.id
  transit_gateway_route_table_id = var.transit_gateway_outputs.main_tgw_egress_route_table_id
}
