output "environment" {
  value = var.environment
}
output "region" {
  value = var.region
}
output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "vpc_name" {
  value = var.vpc_name
}

output "vpc_cidr_block" {
  value = aws_vpc.vpc.cidr_block
}

output "keypair_name" {
  value = var.keypair_name
}

output "is_networkhub_vpc" {
  value = var.is_networkhub_vpc
}
output "my_security_group_id" {
  value = aws_security_group.default.id
}
output "subnet_ids" {
  value = local.subnet_ids
}
output "public_route_table_id" {
  value = aws_route_table.public.id
}
output "private_primary_route_table_id" {
  value = aws_route_table.private_primary.id
}
output "private_secondary_route_table_id" {
  value = aws_route_table.private_secondary.id
}
output "transit_gateway_vpc_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.egress_vpc.id
}