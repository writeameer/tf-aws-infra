variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_max_capacity" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "node_min_capacity" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-demo"
}