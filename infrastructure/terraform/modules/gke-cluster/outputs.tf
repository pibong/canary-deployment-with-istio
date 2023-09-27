output "ca_certificate" {
  description = "Public certificate of the cluster (base64-encoded)."
  value       = google_container_cluster.cluster.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "cluster" {
  description = "Cluster resource."
  sensitive   = true
  value       = google_container_cluster.cluster
}

output "endpoint" {
  description = "Cluster endpoint."
  value       = google_container_cluster.cluster.endpoint
}

output "id" {
  description = "Fully qualified cluster id."
  value       = google_container_cluster.cluster.id
}

output "location" {
  description = "Cluster location."
  value       = google_container_cluster.cluster.location
}

output "master_version" {
  description = "Master version."
  value       = google_container_cluster.cluster.master_version
}

output "name" {
  description = "Cluster name."
  value       = google_container_cluster.cluster.name
}

output "notifications" {
  description = "GKE PubSub notifications topic."
  value       = try(google_pubsub_topic.notifications[0].id, null)
}

output "self_link" {
  description = "Cluster self link."
  sensitive   = true
  value       = google_container_cluster.cluster.self_link
}

output "workload_identity_pool" {
  description = "Workload identity pool."
  value       = "${var.project_id}.svc.id.goog"
  depends_on = [
    google_container_cluster.cluster
  ]
}
