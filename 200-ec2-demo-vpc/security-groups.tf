# security-groups.tf
# Centralized security group management for multi-tier architecture

locals {
  vpc_cidr = data.aws_vpc.vpc.cidr_block
  
  # Common ports by service
  ssh_port    = 22
  http_port   = 80
  https_port  = 443
  mysql_port  = 3306
  postgres_port = 5432
  app_port    = 8080
}

#############################################
# Tier 1 (Public/Web) Security Group
#############################################
resource "aws_security_group" "tier1_sg" {
  name_prefix = "tier1-web-"
  description = "Security group for Tier 1 (public/web) instances"
  vpc_id      = data.aws_vpc.vpc.id

  # Inbound Rules
  ingress {
    description = "SSH from anywhere (consider restricting in production)"
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet"
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP for testing/debugging
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.vpc_cidr]
  }

  # All outbound traffic (web servers need internet access)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tier1-web-sg"
    Tier = "1"
    Purpose = "Web/Load Balancer tier"
  }
}

#############################################
# Tier 2 (App) Security Group - CRITICAL FOR TESTING
#############################################
resource "aws_security_group" "tier2_sg" {
  name_prefix = "tier2-app-"
  description = "Security group for Tier 2 (application) instances"
  vpc_id      = data.aws_vpc.vpc.id

  # Inbound Rules
  ingress {
    description     = "SSH from Tier 1"
    from_port       = local.ssh_port
    to_port         = local.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.tier1_sg.id]
  }

  ingress {
    description     = "Application port from Tier 1"
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.tier1_sg.id]
  }

  # Self-referencing for inter-app communication
  ingress {
    description = "Inter-app communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # ICMP for testing
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.vpc_cidr]
  }

  # CRITICAL: All outbound for internet connectivity testing via TGW
  egress {
    description = "All outbound traffic - required for TGW to Inspection VPC to Internet path"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tier2-app-sg"
    Tier = "2"
    Purpose = "Application tier - TGW internet testing"
  }
}

#############################################
# Tier 3 (Data) Security Group
#############################################
resource "aws_security_group" "tier3_sg" {
  name_prefix = "tier3-data-"
  description = "Security group for Tier 3 (data/database) instances"
  vpc_id      = data.aws_vpc.vpc.id

  # Inbound Rules - Only from Tier 2
  ingress {
    description     = "MySQL from Tier 2"
    from_port       = local.mysql_port
    to_port         = local.mysql_port
    protocol        = "tcp"
    security_groups = [aws_security_group.tier2_sg.id]
  }

  ingress {
    description     = "PostgreSQL from Tier 2"
    from_port       = local.postgres_port
    to_port         = local.postgres_port
    protocol        = "tcp"
    security_groups = [aws_security_group.tier2_sg.id]
  }

  ingress {
    description     = "SSH from Tier 2 for maintenance"
    from_port       = local.ssh_port
    to_port         = local.ssh_port
    protocol        = "tcp"
    security_groups = [aws_security_group.tier2_sg.id]
  }

  # ICMP for testing
  ingress {
    description = "ICMP from app tier"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    security_groups = [aws_security_group.tier2_sg.id]
  }

  # Limited outbound - only HTTPS for updates/patches
  egress {
    description = "HTTPS for updates"
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS for resolution
  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tier3-data-sg"
    Tier = "3"
    Purpose = "Database/Data tier"
  }
}

#############################################
# VPC Endpoints Security Group
#############################################
resource "aws_security_group" "vpc_endpoints_sg" {
  name_prefix = "vpc-endpoints-"
  description = "Security group for VPC endpoints (SSM, EC2Messages, etc.)"
  vpc_id      = data.aws_vpc.vpc.id

  # Allow HTTPS from all tiers for SSM access
  ingress {
    description = "HTTPS from all tiers for SSM"
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  # No outbound rules needed for interface endpoints
  
  tags = {
    Name = "vpc-endpoints-sg"
    Purpose = "SSM and other VPC endpoints"
  }
}

#############################################
# Debugging/Testing Security Group (Optional)
#############################################
resource "aws_security_group" "debug_sg" {
  name_prefix = "debug-testing-"
  description = "Temporary security group for network debugging - REMOVE IN PRODUCTION"
  vpc_id      = data.aws_vpc.vpc.id

  # Allow all inbound from VPC for testing
  ingress {
    description = "All from VPC for debugging"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr]
  }

  # Allow all outbound for testing
  egress {
    description = "All outbound for testing"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "debug-testing-sg"
    Purpose = "TEMPORARY - Network debugging only"
    Environment = "testing"
  }
}