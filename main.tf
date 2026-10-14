terraform {
  # TFDoctor supplies the endpoint, locking and run-scoped credentials.
  backend "http" {}

  required_version = "= 1.14.2"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "= 2.22.0"
    }
  }
}

# Credentials are supplied by the TFDoctor Workspace.
provider "ovh" {
  endpoint = "ovh-eu"
}

variable "ovh_project_id" {
  description = "OVHcloud project identity, supplied through TFDoctor Workspace inputs."
  type        = string

  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.ovh_project_id))
    error_message = "Provide the OVHcloud Public Cloud project identifier."
  }
}

locals {
  bucket_names = toset([
    for number in range(1, 9) : format("tfdoctor-bar-smoke-7a9e46-%02d", number)
  ])
}

# Eight empty buckets: no instances, volumes, uploaded objects or paid add-ons.
# Explicit identity avoids the provider's environment-fallback Plan/State mismatch.
# The project identifier remains in the Workspace inputs rather than in Git.
resource "ovh_cloud_project_storage" "smoke" {
  for_each = local.bucket_names

  service_name = var.ovh_project_id
  name         = each.key
  region_name  = "DE"
  hide_objects = true

  encryption = {
    sse_algorithm = "AES256"
  }
}

output "bucket_names" {
  description = "The eight test bucket names."
  value       = sort([for bucket in ovh_cloud_project_storage.smoke : bucket.name])
}

output "region" {
  description = "OVHcloud Object Storage region."
  value       = "DE"
}
