output "vpc_id" {
  description = "VPC ID"
  value       = var.create_network == "true" ? aws_vpc.vpc[0].id : data.aws_vpc.existing[0].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public.*.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = var.create_network == "true" ? aws_vpc.vpc[0].cidr_block : data.aws_vpc.existing[0].cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = var.create_network == "true" ? aws_internet_gateway.igw[0].id : ""
}

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = var.create_network == "true" ? aws_route_table.public[0].id : ""
}

output "security_group_id" {
  description = "Security group ID for HTTP/HTTPS traffic"
  value       = var.create_network == "true" ? aws_security_group.allow_http_https[0].id : ""
}
