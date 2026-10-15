variable "lab_release" {
  description = "Changing this replaces only State-only release/application/handoff resources."
  type        = number
  default     = 1
  validation {
    condition     = var.lab_release >= 1 && var.lab_release <= 10 && floor(var.lab_release) == var.lab_release
    error_message = "lab_release must be an integer from 1 to 10."
  }
}

variable "lab_note" {
  description = "Changing this updates the count-based State-only replicas in place."
  type        = string
  default     = "baseline"
}

variable "lab_replica_count" {
  description = "One to three State-only replicas; zero intentionally fails validation."
  type        = number
  default     = 2
  validation {
    condition     = var.lab_replica_count >= 1 && var.lab_replica_count <= 3 && floor(var.lab_replica_count) == var.lab_replica_count
    error_message = "lab_replica_count must be 1, 2 or 3."
  }
}

variable "lab_check_names" {
  description = "Keys for State-only for_each checks. These names create no monitoring service."
  type        = set(string)
  default     = ["health", "inventory"]
  validation {
    condition     = length(var.lab_check_names) >= 1 && length(var.lab_check_names) <= 3 && alltrue([for name in var.lab_check_names : contains(["health", "inventory", "routing"], name)])
    error_message = "Choose one to three unique names from health, inventory and routing."
  }
}

variable "lab_output_note" {
  description = "Changes a Terraform output without changing resource inputs."
  type        = string
  default     = "baseline output"
}

variable "lab_sensitive_example" {
  description = "Public dummy value used only to verify sensitive-field masking. Never put real credentials here."
  type        = string
  default     = "PUBLIC-DEMO-NOT-A-REAL-SECRET"
  sensitive   = true
}

variable "lab_health_ok" {
  description = "False demonstrates a Terraform check warning; this does not monitor OVH health."
  type        = bool
  default     = true
}

variable "lab_fail_apply" {
  description = "Opt-in intentional postcondition failure on a replaced State-only resource. Never enabled by default."
  type        = bool
  default     = false
}
