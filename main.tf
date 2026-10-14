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

# Credentials and project identity are supplied by the TFDoctor Workspace.
provider "ovh" {
  endpoint = "ovh-eu"
}

locals {
  bucket_names = toset([
    for number in range(1, 9) : format("tfdoctor-bar-smoke-7a9e46-%02d", number)
  ])
}

# Eight empty buckets: no instances, volumes, uploaded objects or paid add-ons.
# OVH_CLOUD_PROJECT_SERVICE selects the project without putting its ID in Git.
resource "ovh_cloud_project_storage" "smoke" {
  for_each = local.bucket_names

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
