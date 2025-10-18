terraform {
  backend "s3" {
    bucket = "tfstate-47a66729"
    key    = "foundation/310-eks-addons.tfstate"
    region = "me-central-1"
  }
}
