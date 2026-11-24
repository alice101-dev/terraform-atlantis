variable "project_id" {
  description = "GCP Project ID where APIs will be enabled."
  type        = string
}

variable "enabled_apis" {
  description = "List of Google Cloud API service names to enable in the project."
  type        = list(string)
}

variable "disable_on_destroy" {
  description = "Whether to disable the API when the resource is destroyed. Set to false to avoid accidental service disruption."
  type        = bool
  default     = false
}

variable "service_identities" {
  description = "API yang service agent-nya dibuat (mis. sqladmin.googleapis.com). Harus juga ada di enabled_apis."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for s in var.service_identities : contains(var.enabled_apis, s)])
    error_message = "Setiap service_identities harus juga ada di enabled_apis (API harus aktif sebelum service agent dibuat)."
  }
}
