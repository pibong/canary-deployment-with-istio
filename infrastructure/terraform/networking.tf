module "network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 7.3"

  project_id   = var.project_id
  network_name = local.network_name

  subnets = [
    {
      subnet_name           = local.subnet_name
      subnet_ip             = local.subnet_cidr
      subnet_region         = var.region
      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    (local.subnet_name) = [
      {
        range_name    = local.pods_range_name
        ip_cidr_range = local.pods_cidr
      },
      {
        range_name    = local.services_range_name
        ip_cidr_range = local.services_cidr
      },
    ]
  }

  ingress_rules = [
    {
      name          = "${local.prefix_name}-master-to-istio-webhook"
      description   = "Needed by the Istio Pilot discovery validation webhook in private GKE"
      source_ranges = [local.master_cidr]
      target_tags   = local.node_pool_tags
      allow = [
        {
          protocol = "tcp"
          port     = ["15017"]
        }
      ]
    }
  ]
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 6.0"
  name    = "${local.prefix_name}-cloud-router"
  project = var.project_id
  network = module.network.network_name
  region  = var.region

  nats = [{
    name                               = "${local.prefix_name}-nat-gateway"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  }]
}

/*
module "dns-public-zone" {
  source  = "terraform-google-modules/cloud-dns/google"
  version = "~> 5.1"

  project_id                         = var.project_id
  type                               = "public"
  name                               = local.mz_name
  domain                             = local.domain
  private_visibility_config_networks = [module.network.network_self_link]
}
*/
