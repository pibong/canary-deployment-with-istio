output "gke_endpoint" {
  description = "Cluster endpoint"
  value       = module.gke.endpoint
}

output "gke_name" {
  description = "Cluster name"
  value       = local.prefix_name
}

output "gke_zone" {
  description = "Cluster zone"
  value       = var.zone
}
