# Fetch the current public IP of the machine running terraform
data "http" "myip" {
  url = "https://checkip.amazonaws.com/"
  request_headers = {
    Accept = "text/plain"
  }
}

locals {
  # Compose the current IP as a /32. trimspace() to drop trailing newline.
  current_ip_cidr = "${trimspace(data.http.myip.response_body)}/32"

  # Just use the current IP - much simpler!
  public_access_cidrs = [local.current_ip_cidr]
}
