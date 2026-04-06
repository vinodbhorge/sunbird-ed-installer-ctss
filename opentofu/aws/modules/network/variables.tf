variable "environment" {
  description = "Environment name"
  type        = string
}

variable "building_block" {
  description = "Building block name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "create_network" {
  description = "Whether to create a new VPC (true) or use existing (false)"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_config" {
  description = <<-EOT
    Map of logical subnet name to configuration. The subnet CIDR is derived as:
      cidrsubnet(vpc_cidr, 8, cidr_netnum)

    Fields:
      type              - "public" or "private" (required)
      availability_zone - AZ suffix, e.g. "a", "b", "c" (required)
      cidr_netnum       - unique integer offset for cidrsubnet(), e.g. 101, 102, 201, 202 (required)

    Public subnets  -> Internet Gateway route, map_public_ip_on_launch = true.
    Private subnets -> NAT Gateway route (when nat_gateway_enabled = true), no public IPs.
  EOT
  type = map(object({
    type              = string
    availability_zone = string
    cidr_netnum       = number
  }))
  default = {
    public-a = { type = "public", availability_zone = "a", cidr_netnum = 101 }
    public-b = { type = "public", availability_zone = "b", cidr_netnum = 102 }
  }

  validation {
    condition = alltrue([
      for k, v in var.subnet_config : contains(["public", "private"], v.type)
    ])
    error_message = "Each subnet 'type' must be either \"public\" or \"private\"."
  }

  validation {
    condition = length(var.subnet_config) == length(distinct([
      for k, v in var.subnet_config : v.cidr_netnum
    ]))
    error_message = "Each subnet must have a unique cidr_netnum to avoid CIDR conflicts."
  }
}

variable "nat_gateway_enabled" {
  description = <<-EOT
    Create a NAT Gateway so private subnets can reach the internet.
    Requires at least one public subnet (NAT GW is placed in the first public subnet).
    Set to false for fully isolated private subnets or to save cost in non-prod environments.
  EOT
  type    = bool
  default = true
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed for HTTP/HTTPS inbound traffic on the shared security group"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  description = "Existing VPC ID (required if create_network is false)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs (required if create_network is false)"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs (required if create_network is false)"
  type        = list(string)
  default     = []
}
