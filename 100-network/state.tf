terraform {
  backend "s3" {
    bucket = "tfstate-47a66729"
    key    = "foundation/100-network.tfstate"
    region = "me-central-1"
  }  
}
