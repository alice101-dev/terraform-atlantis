variable "network_vpc_name" {
  description = "Nama unik untuk VPC (contoh: prod-vpc-jakarta)"
  type        = string
}

variable "vpc_id" {
  description = "The self-link ID of the VPC network to apply firewall rules to"
  type        = string
}

variable "firewall_rules" {
  description = "List of firewall rules to create"
  type = map(object({
    direction          = optional(string, "INGRESS")
    priority           = optional(number, 1000)
    source_ranges      = optional(list(string))
    destination_ranges = optional(list(string))
    source_tags        = optional(list(string))
    target_tags        = optional(list(string))
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    description = optional(string)
    disabled    = optional(bool, false)
    log_config = optional(object({
      metadata = optional(string, "INCLUDE_ALL_METADATA")
    }))
  }))
  default = {}

  # Defense-in-depth untuk yang checkov tak bisa scan (for_each dari tfvars):
  # tolak INGRESS dari 0.0.0.0/0 yang membuka SSH (22) atau RDP (3389).
  validation {
    condition = alltrue([
      for k, r in var.firewall_rules :
      !(
        r.direction == "INGRESS" &&
        contains((r.source_ranges == null ? [] : r.source_ranges), "0.0.0.0/0") &&
        anytrue([
          for a in r.allow :
          contains((a.ports == null ? [] : a.ports), "22") ||
          contains((a.ports == null ? [] : a.ports), "3389")
        ])
      )
    ])
    error_message = "Firewall: INGRESS dari 0.0.0.0/0 dilarang membuka SSH (22) atau RDP (3389). Batasi source_ranges (mis. range IAP 35.235.240.0/20)."
  }
}
