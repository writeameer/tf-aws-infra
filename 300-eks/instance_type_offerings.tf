# Returns only the types from var.node_instance_types that are actually offered in this region
data "aws_ec2_instance_type_offerings" "regional_supported" {
  location_type = "region"

  filter {
    name   = "instance-type"
    values = var.node_instance_types
  }
}

locals {
  supported_instance_types = try(data.aws_ec2_instance_type_offerings.regional_supported.instance_types, [])
}

# Fail early with a helpful message if none of the requested types are available
resource "null_resource" "validate_instance_types" {
  lifecycle {
    precondition {
      condition     = length(local.supported_instance_types) > 0
      error_message = "None of the requested instance types (${join(", ", var.node_instance_types)}) are offered in this region. Try t4g.small or t4g.micro."
    }
  }
}
