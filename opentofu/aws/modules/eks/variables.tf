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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for EKS cluster and load balancers"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_disk_size_gb" {
  description = "Disk size for worker nodes in GB"
  type        = number
  default     = 30
}

variable "node_count_min" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_count_max" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "private_ingressgateway_ip" {
    type        = string
    description = "Nginx private ingress ip."
    default = "10.0.0.10"
}

variable "cloudwatch_enabled_log_types" {
  description = "EKS control plane log types to ship to CloudWatch Logs"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "enable_cloudwatch_observability" {
  description = "Deploy the amazon-cloudwatch-observability EKS add-on for Container Insights"
  type        = bool
  default     = false
}
