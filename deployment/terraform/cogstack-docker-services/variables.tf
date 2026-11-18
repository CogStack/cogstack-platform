
variable "hosts" {
  type = map(object({
    ip_address  = string,
    unique_name = string,
    name        = string
  }))
  description = "Created Hosts: A map of { hostname: { data } }"
}

variable "ssh_private_key_file" {
  type        = string
  description = "A filepath to a SSH Private key that is used to SSH login to created hosts"
}

variable "service_targets" {
  type = object({
    medcat_service = object({
      hostname              = string,
      environment_variables = optional(list(string), ["APP_MEDCAT_MODEL_PACK=/cat/models/examples/example-medcat-v1-model-pack.zip"])
    })
    observability = object({
      hostname = string
    })
  })
  description = "Target Hosts: A map of { service_name: {hostname: host, environment_variables [ 'some_var: some value' ]} }. The hostname must be a host passed in the hosts variable"
  validation {
    condition     = contains(keys(var.hosts), var.service_targets.medcat_service.hostname) && contains(keys(var.hosts), var.service_targets.observability.hostname)
    error_message = "The hostname put here must also be passed in as a key in the hosts variable"
  }
}

