variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "demo-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.33"
}

variable "node_instance_types" {
  description = "Preferred instance types (ordered). Only region-supported types will be used."
  type        = list(string)
  default     = ["t4g.small", "t4g.micro"]
}

variable "desired_size" {
  description = "Desired node count"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Min node count"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Max node count"
  type        = number
  default     = 4
}

variable "use_spot" {
  description = "Use SPOT capacity for the default node group (cheaper, interruptible)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to EKS resources"
  type        = map(string)
  default     = {
    Project = "foundation"
    Stack   = "demo"
  }
}

variable "static_allowed_cidrs" {
  description = "Static CIDR allowlist for EKS public endpoint"
  type        = list(string)
  default     = ["82.178.17.251/32"]
}

variable "include_current_ip" {
  description = "Auto-include the current public IP/32 in the allowlist"
  type        = bool
  default     = true
}
