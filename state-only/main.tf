# Optional separate Workspace root for State/history/restore tests.
# Every resource is builtin and State-only; there is no cloud provider.
terraform {
  backend "http" {}
  required_version = "= 1.14.2"
}

variable "generation" {
  type    = number
  default = 1
  validation {
    condition     = var.generation >= 1 && var.generation <= 10 && floor(var.generation) == var.generation
    error_message = "generation must be an integer from 1 to 10."
  }
}

resource "terraform_data" "catalog" {
  input = {
    generation = var.generation
    labels     = ["state-only", "restore-test"]
    metadata   = { owner = "test", cloud_resources = 0 }
  }
}

resource "terraform_data" "application" {
  input            = terraform_data.catalog.output
  triggers_replace = terraform_data.catalog.output.generation
}

module "checks" {
  source = "../modules/checks"

  application_id       = terraform_data.application.id
  replica_count        = 2
  check_names          = ["health", "inventory"]
  note                 = "state-only workspace"
  demo_sensitive_value = "PUBLIC-DEMO-NOT-A-REAL-SECRET"
}

output "inventory" {
  value = {
    generation     = var.generation
    application_id = terraform_data.application.id
    replicas       = module.checks.replica_ids
    checks         = module.checks.check_ids
  }
}
