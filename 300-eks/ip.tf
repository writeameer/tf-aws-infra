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

  # Final allowlist = static + (optionally) current machine IP
  # We avoid a top-level ternary by pushing it inside concat().
  public_access_cidrs = distinct(
    concat(
      var.static_allowed_cidrs,
      var.include_current_ip ? [local.current_ip_cidr] : []
    )
  )
}
