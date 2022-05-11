output "main_transit_gateway_id" {
  value      = aws_ec2_transit_gateway.main.id
  depends_on = [aws_ec2_transit_gateway.main]
}

output "main_tgw_egress_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.main_tgw_egress.id
}

output "main_tgw_internal_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.main_tgw_internal.id
}


