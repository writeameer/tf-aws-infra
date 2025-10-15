provider "aws" {
  region = "me-central-1"
}

# Needed to fetch your current public IP at apply time
provider "http" {}
