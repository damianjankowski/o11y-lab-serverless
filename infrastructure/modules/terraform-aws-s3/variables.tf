variable "name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "versioning_status" {
  description = "Enable or disable bucket versioning"
  type        = string
  default     = "Enabled"
}

variable "server_side_encryption_configuration" {
  description = "Map containing server-side encryption configuration"
  type        = any
  default     = {}
}

variable "force_destroy" {
  description = "Set to true to allow deletion of non-empty S3 bucket"
  type        = bool
  default     = false
}

variable "block_public_acls" {
  description = "Block public ACLs"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
  type        = bool
  default     = true
}

variable "enable_personal_access_policy" {
  description = "Enable personal access policy for specific users"
  type        = bool
  default     = false
}

variable "personal_user_arns" {
  description = "List of IAM user ARNs that should have personal access to the bucket"
  type        = list(string)
  default     = []
}
