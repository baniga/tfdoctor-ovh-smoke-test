run "baseline" {
  command = apply
  assert {
    condition     = length(module.checks.replica_ids) == 2 && length(module.checks.check_ids) == 2
    error_message = "Expected six builtin resources in the separate State-only root."
  }
}

run "generation_change" {
  command = plan
  variables { generation = 2 }
}

run "invalid_generation" {
  command = plan
  variables { generation = 0 }
  expect_failures = [var.generation]
}
