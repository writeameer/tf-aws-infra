# variable "vpc_cidr" {
#   description = "CIDR block for VPC - using /16 for large IP space (65,536 IPs)"
#   type        = string
#   default     = "10.0.0.0/16"
# }

# variable "tier1_subnet_cidrs" {
#   description = "CIDR blocks for public subnets"
#   type        = list(string)
#   default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
# }

# variable "tier2_subnet_cidrs" {
#   description = "CIDR blocks for private subnets"
#   type        = list(string)
#   default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
# }

# variable "tier3_subnet_cidrs" {
#   description = "CIDR blocks for private subnets"
#   type        = list(string)
#   default     = ["10.0.100.0/24", "10.0.200.0/24", "10.0.300.0/24"]
# }


#############################################
# Variables
#############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tier1_subnet_cidrs" {
  description = "CIDRs for Tier1 (public) subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "tier2_subnet_cidrs" {
  description = "CIDRs for Tier2 (application) subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "tier3_subnet_cidrs" {
  description = "CIDRs for Tier3 (data) subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.40.0/24", "10.0.50.0/24", "10.0.60.0/24"]
}

## Adding vars for Inspection VPC

variable "inspection_vpc_cidr" {
  type        = string
  description = "CIDR for Inspection/Egress VPC"
  default     = "10.100.0.0/16"
}

variable "insp_public_cidrs" {
  type        = list(string)
  description = "Public subnets (for NAT/IGW) across AZs"
  default     = ["10.100.1.0/24","10.100.2.0/24","10.100.3.0/24"]
}
variable "insp_tgw_cidrs" {
  type        = list(string)
  description = "TGW attachment subnets across AZs"
  default     = ["10.100.10.0/24","10.100.20.0/24","10.100.30.0/24"]
}