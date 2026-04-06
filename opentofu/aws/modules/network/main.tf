# ---------------------------------------------------------------------------------------------------------------------
# Create the VPC Network & corresponding Internet Gateway
# ---------------------------------------------------------------------------------------------------------------------

locals {
  environment_name = "${var.building_block}-${var.environment}"
  
  common_tags = {
    Environment    = var.environment
    BuildingBlock  = var.building_block
    ManagedBy      = "Terraform"
    CloudProvider  = "AWS"
  }
}

# VPC
resource "aws_vpc" "vpc" {
  count = var.create_network ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment_name}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  count = var.create_network ? 1 : 0

  vpc_id = aws_vpc.vpc[0].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment_name}-igw"
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Public Subnet Configuration
# Public internet access is configured via Internet Gateway
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.create_network ? var.subnet_count : 0

  vpc_id                  = aws_vpc.vpc[0].id
  cidr_block              = cidrsubnet(aws_vpc.vpc[0].cidr_block, 8, var.subnet_cidr_offset + count.index)
  availability_zone       = "${var.aws_region}${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name                                                    = "${local.environment_name}-public-subnet-${element(var.availability_zones, count.index)}"
      "kubernetes.io/role/elb"                                = "1"
      "kubernetes.io/cluster/${local.environment_name}-cluster" = "shared"
      Tier                                                    = "Public"
    }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  count = var.create_network ? 1 : 0

  vpc_id = aws_vpc.vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment_name}-public-rt"
    }
  )
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count = var.create_network ? var.subnet_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# ---------------------------------------------------------------------------------------------------------------------
# Security Group for allowing HTTP/HTTPS traffic
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "allow_http_https" {
  count = var.create_network ? 1 : 0

  name        = "${local.environment_name}-allow-http-https"
  description = "Allow HTTP and HTTPS inbound traffic"
  vpc_id      = aws_vpc.vpc[0].id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment_name}-allow-http-https"
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Data sources for existing VPC (if create_network is false)
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "existing" {
  count = var.create_network ? 0 : 1
  id    = var.vpc_id
}

data "aws_subnets" "existing_public" {
  count = var.create_network ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  tags = {
    Tier = "Public"
  }
}
