variable "cluster_name" {
  description = "Existing EKS cluster name (from 300-eks)"
  type        = string
  default     = "demo-eks"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "me-central-1"
}

variable "namespace" {
  description = "Namespace to install Karpenter"
  type        = string
  default     = "karpenter"
}
