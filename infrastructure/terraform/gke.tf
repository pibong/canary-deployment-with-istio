data "google_compute_zones" "available" {}

module "gke" {
  source = "./modules/gke-cluster"

  project_id  = var.project_id
  name        = local.prefix_name
  description = local.prefix_name
  location    = var.zone

  private_cluster_config = {
    enable_private_endpoint = false
    master_global_access    = false
  }

  vpc_config = {
    network    = module.network.network_self_link
    subnetwork = module.network.subnets_self_links[0]

    secondary_range_names = {
      pods     = local.pods_range_name
      services = local.services_range_name
    }

    master_authorized_ranges = {
      my-ip = var.my_source_address
    }

    master_ipv4_cidr_block = local.master_cidr
  }

  enable_addons = {
    gce_persistent_disk_csi_driver = true
    horizontal_pod_autoscaling     = true
    http_load_balancing            = true
  }

  cluster_autoscaling = {
    cpu_limits = {
      min = 5
      max = 12
    }
    mem_limits = {
      min = 8
      max = 48
    }
  }

  logging_config = {
    enable_system_logs    = true
    enable_workloads_logs = true
  }

  monitoring_config = {
    enable_system_metrics      = true
    enable_daemonset_metrics   = true
    enable_deployment_metrics  = true
    enable_hpa_metrics         = true
    enable_pod_metrics         = true
    enable_statefulset_metrics = true
    enable_storage_metrics     = true

    enable_managed_prometheus = true
  }

  depends_on = [module.network]
}

module "gke-node-pool-1" {
  source = "./modules/gke-nodepool"

  cluster_id        = module.gke.id
  cluster_name      = module.gke.name
  name              = local.node_pool_name
  project_id        = var.project_id
  location          = var.zone
  max_pods_per_node = 110

  node_locations = [var.zone]

  node_config = {
    disk_size_gb = 50
    machine_type = "e2-standard-2"
    shielded_instance_config = {
      enable_integrity_monitoring = true
      enable_secure_boot          = true
    }
  }

  nodepool_config = {
    autoscaling = {
      max_node_count = 6
      min_node_count = 2
    }
    management = {
      auto_repair  = true
      auto_upgrade = true
    }
  }

  tags = local.node_pool_tags
}
