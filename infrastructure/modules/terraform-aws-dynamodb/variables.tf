variable "table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}

variable "billing_mode" {
  description = "The billing mode for the table. Either PROVISIONED or PAY_PER_REQUEST"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "read_capacity" {
  description = "The number of read capacity units for the table (required if billing_mode is PROVISIONED)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "The number of write capacity units for the table (required if billing_mode is PROVISIONED)"
  type        = number
  default     = 5

}

variable "hash_key" {
  description = "The hash key for the table"
  type        = string
}

variable "range_key" {
  description = "The range key for the table"
  type        = string
  default     = null
}

variable "attributes" {
  description = "A list of attribute definitions for the table"
  type = list(object({
    name = string
    type = string
  }))
  default = []

  validation {
    condition = alltrue([
      for attr in var.attributes : contains(["S", "N", "B"], attr.type)
    ])
    error_message = "Attribute type must be one of: S (String), N (Number), B (Binary)."
  }
}

variable "enable_ttl" {
  description = "Enable Time to Live (TTL) for the table"
  type        = bool
  default     = false
}

variable "ttl_attribute" {
  description = "The attribute name to use for TTL"
  type        = string
  default     = "ttl_timestamp"
}

variable "global_secondary_indexes" {
  description = "A list of global secondary indexes to create on the table"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = string
    projection_type    = string
    non_key_attributes = list(string)
    read_capacity      = number
    write_capacity     = number
  }))
  default = []
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for the table"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable server-side encryption for the table"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = map(string)
  default     = {}
}
