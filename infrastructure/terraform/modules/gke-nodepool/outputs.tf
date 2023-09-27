output "id" {
  description = "Fully qualified nodepool id."
  value       = google_container_node_pool.nodepool.id
}

output "name" {
  description = "Nodepool name."
  value       = google_container_node_pool.nodepool.name
}

output "service_account_email" {
  description = "Service account email."
  value       = local.service_account_email
}

output "service_account_iam_email" {
  description = "Service account email."
  value = format(
    "serviceAccount:%s",
    local.service_account_email == null ? "" : local.service_account_email
  )
}
