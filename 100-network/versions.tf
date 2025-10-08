terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    awsutils = {
      source = "cloudposse/awsutils"
      # For local development,
      # install the provider on local computer by running `make install` from the root of the repo, and uncomment the 
      # version below
      # version = "9999.99.99"
    }    
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }

    
  }
}


