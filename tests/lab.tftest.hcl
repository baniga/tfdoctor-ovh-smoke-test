# All OVH operations below use Terraform's in-memory mock provider.
# No OVH account, credentials, HTTP backend or real cloud resources are used.
mock_provider "ovh" {
  mock_resource "ovh_cloud_project_storage" {
    defaults = {
      created_at = "2026-10-15T00:00:00Z"
    }
  }
}

variables {
  ovh_project_id    = "00000000000000000000000000000000"
  lab_release       = 1
  lab_note          = "baseline"
  lab_replica_count = 2
  lab_check_names   = ["health", "inventory"]
  lab_output_note   = "baseline output"
  lab_health_ok     = true
  lab_fail_apply    = false
}

run "baseline" {
  command = apply
  assert {
    condition     = length(ovh_cloud_project_storage.smoke) == 8 && length(module.checks.replica_ids) == 2 && length(module.checks.check_ids) == 2
    error_message = "Expected eight mocked buckets and the baseline count/for_each instances."
  }
  assert {
    condition     = length(terraform_data.catalog.output.buckets) == 8 && terraform_data.application.output.catalog.region == "DE"
    error_message = "The application must retain its link to the bucket catalog."
  }
}

run "no_changes" {
  command = plan
}

run "update" {
  command = plan
  variables { lab_note = "updated replica note" }
}

run "replace" {
  command = plan
  variables { lab_release = 2 }
}

run "scale_down" {
  command = plan
  variables {
    lab_replica_count = 1
    lab_check_names   = ["health"]
  }
}

run "scale_up" {
  command = plan
  variables {
    lab_replica_count = 3
    lab_check_names   = ["health", "inventory", "routing"]
  }
}

run "output_only" {
  command = plan
  variables { lab_output_note = "output changed; resource inputs unchanged" }
}

run "validation_failure" {
  command = plan
  variables { lab_replica_count = 0 }
  expect_failures = [var.lab_replica_count]
}

run "check_warning" {
  command = plan
  variables { lab_health_ok = false }
  expect_failures = [check.lab_health]
}

run "failed_apply_plan" {
  command = plan
  variables { lab_fail_apply = true }
}

run "expected_apply_failure" {
  command = apply
  variables { lab_fail_apply = true }
  expect_failures = [terraform_data.handoff]
}
