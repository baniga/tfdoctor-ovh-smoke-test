# These eight additional instances only store values in Terraform State.
# No provisioners, cloud API calls, instances, objects or paid add-ons.
resource "terraform_data" "catalog" {
  input = {
    environment = "tfdoctor-test"
    region      = "DE"
    buckets = {
      for name, bucket in ovh_cloud_project_storage.smoke : name => {
        id     = bucket.id
        name   = bucket.name
        region = bucket.region_name
      }
    }
  }
}

resource "terraform_data" "release" {
  input            = { version = var.lab_release }
  triggers_replace = var.lab_release
}

resource "terraform_data" "application" {
  input = {
    catalog = terraform_data.catalog.output
    release = terraform_data.release.output
  }

  triggers_replace = [terraform_data.release.output]
  depends_on       = [terraform_data.release]
}

resource "terraform_data" "handoff" {
  input            = { application_id = terraform_data.application.id }
  triggers_replace = [var.lab_fail_apply]

  lifecycle {
    replace_triggered_by = [terraform_data.application]
    postcondition {
      condition     = !var.lab_fail_apply || self.id == ""
      error_message = "Intentional State-only Apply failure. Select main and review the recovery Plan."
    }
  }
}

module "checks" {
  source = "./modules/checks"

  application_id       = terraform_data.handoff.id
  replica_count        = var.lab_replica_count
  check_names          = var.lab_check_names
  note                 = var.lab_note
  demo_sensitive_value = var.lab_sensitive_example
}

check "lab_health" {
  assert {
    condition     = var.lab_health_ok
    error_message = "Intentional lab check warning: set lab_health_ok back to true."
  }
}

output "lab_summary" {
  description = "State-only test resources and their links to the real empty buckets."
  value = {
    application_id = terraform_data.application.id
    handoff_id     = terraform_data.handoff.id
    release        = terraform_data.release.output
    bucket_names   = sort(keys(ovh_cloud_project_storage.smoke))
    replica_ids    = module.checks.replica_ids
    check_ids      = module.checks.check_ids
  }
}

output "lab_output_note" {
  description = "Change only lab_output_note to test an output-only Plan."
  value       = var.lab_output_note
}

output "lab_sensitive_example" {
  description = "A public dummy string, deliberately marked sensitive to test masking."
  value       = module.checks.sensitive_example
  sensitive   = true
}
