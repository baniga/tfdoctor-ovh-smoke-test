variable "application_id" { type = string }
variable "replica_count" { type = number }
variable "check_names" { type = set(string) }
variable "note" { type = string }
variable "demo_sensitive_value" {
  type      = string
  sensitive = true
}

resource "terraform_data" "replica" {
  count = var.replica_count

  input = {
    application_id = var.application_id
    replica_index  = count.index
    note           = var.note
    metadata = {
      environment = "test"
      labels      = ["tfdoctor", "state-only"]
      limits      = { cloud_instances = 0, uploaded_bytes = 0 }
    }
  }
}

resource "terraform_data" "check" {
  for_each = var.check_names

  input = {
    name                 = each.key
    application_id       = var.application_id
    first_replica_id     = try(terraform_data.replica[0].id, null)
    enabled              = true
    demo_sensitive_value = var.demo_sensitive_value
  }
}

output "replica_ids" { value = [for replica in terraform_data.replica : replica.id] }
output "check_ids" { value = { for name, check in terraform_data.check : name => check.id } }
output "sensitive_example" {
  value     = var.demo_sensitive_value
  sensitive = true
}
