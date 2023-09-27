module "cert_manager_service_account" {
  source       = "terraform-google-modules/service-accounts/google"
  version      = "~> 4.2"
  project_id   = var.project_id
  prefix       = "gsa"
  names        = ["cert-manager"]
  display_name = "Google Service Account for cert-manager"
  description  = "Google Service Account for solving DNS01 challanges"
  project_roles = [
    "${var.project_id}=>roles/dns.admin"
  ]
}

module "cert_manager_iam_bindings" {
  source           = "terraform-google-modules/iam/google//modules/service_accounts_iam"
  version          = "~> 7.7"
  service_accounts = [module.cert_manager_service_account.email]
  project          = var.project_id
  mode             = "additive"
  bindings = {
    "roles/iam.workloadIdentityUser" = [
      "serviceAccount:${var.project_id}.svc.id.goog[${local.cert_manager_namespace}/${local.cert_manager_ksa_name}]"
    ]
  }
}

module "external_dns_service_account" {
  source       = "terraform-google-modules/service-accounts/google"
  version      = "~> 4.2"
  project_id   = var.project_id
  prefix       = "gsa"
  names        = ["external-dns"]
  display_name = "Google Service Account for external-dns"
  description  = "Google Service Account for external-dns"
  project_roles = [
    "${var.project_id}=>roles/dns.admin"
  ]
}

module "external_dns_iam_bindings" {
  source           = "terraform-google-modules/iam/google//modules/service_accounts_iam"
  version          = "~> 7.7"
  service_accounts = [module.external_dns_service_account.email]
  project          = var.project_id
  mode             = "additive"
  bindings = {
    "roles/iam.workloadIdentityUser" = [
      "serviceAccount:${var.project_id}.svc.id.goog[${local.external_dns_namespace}/${local.external_dns_ksa_name}]"
    ]
  }
}
