locals {
  prefix_name = "istio-canary"

  ## GKE networking
  cluster_name        = local.prefix_name
  kubernetes_version  = "1.27.3-gke.100"
  network_name        = "${local.prefix_name}-deployment-network"
  subnet_name         = "${local.prefix_name}-deployment-subnet"
  pods_range_name     = "${local.prefix_name}-deployment-pods-range"
  services_range_name = "${local.prefix_name}-deployment-services-range"
  subnet_cidr         = "10.10.10.0/23"
  pods_cidr           = "192.168.0.0/18"
  services_cidr       = "192.168.64.0/18"
  master_cidr         = "172.16.0.0/28"
  node_pool_name      = "${local.prefix_name}-node-pool-1"
  node_pool_tags      = ["${local.prefix_name}-node"]

  # GKE Workload Identity
  cert_manager_ksa_name  = "cert-manager"
  external_dns_ksa_name  = "external-dns"
  cert_manager_namespace = "cert-manager"
  external_dns_namespace = "external-dns"

  # Cloud DNS
  mz_name = "${local.prefix_name}-public-mz"
  domain  = "DNS_DOMAIN."
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
