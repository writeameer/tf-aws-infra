terraform {
  backend "s3" {
    bucket = "tfstate-47a66729"
    key    = "foundation/200-ec2.tfstate"
    region = "me-central-1"
  }  
}
