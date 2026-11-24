module "vpc" {
  source              = "../../../modules/vpc"
  network_vpc_name    = "${var.env}-${var.network_vpc_name}"
  subnets             = var.subnets
  proxy_only_subnets  = var.proxy_only_subnets
  enable_psa          = var.enable_psa
  psa_prefix_length   = var.psa_prefix_length
  deletion_protection = var.deletion_protection
}
