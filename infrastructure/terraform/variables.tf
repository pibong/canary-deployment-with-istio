variable "project_id" {
  description = "The ID of GCP project"
  type        = string
}

variable "region" {
  description = "The region to host the cluster in"
  type        = string
  default     = "europe-west8"
}

variable "zone" {
  description = "The zone to host the cluster in"
  type        = string
  default     = "europe-west8-a"
}

variable "my_source_address" {
  default = "IP of my local machine. IP is added to GKE's authorized network"
  type    = string

  validation {
    condition     = can(cidrnetmask(var.my_source_address))
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}
