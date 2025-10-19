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

variable "desired_size" {
  description = "Desired node count"
  type        = number
  default     = 4
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

