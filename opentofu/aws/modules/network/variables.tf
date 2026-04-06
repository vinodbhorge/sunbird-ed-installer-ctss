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

variable "subnet_count" {
  description = "Number of public subnets to create"
  type        = number
  default     = 2
}

variable "availability_zones" {
  description = "List of AZ suffixes (e.g. [\"a\", \"b\"]) to spread subnets across"
  type        = list(string)
  default     = ["a", "b"]
}

variable "subnet_cidr_offset" {
  description = "Starting netnum offset passed to cidrsubnet() for public subnets (e.g. 101 yields 10.0.101.0/24, 10.0.102.0/24, ...)"
  type        = number
  default     = 101
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed for HTTP/HTTPS inbound traffic"
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
