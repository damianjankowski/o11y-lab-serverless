variable "ecr_name" {
  description = "The name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "Determines whether image tags can be overwritten in the ECR repository"
  type        = string
  default     = "MUTABLE"
}

variable "image_scanning_enabled" {
  description = "Enables or disables image scanning on image push in the ECR repository"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Enable or disable force deletion of the ECR repository"
  type        = bool
  default     = false
}

variable "encryption_type" {
  description = "The encryption type to use for the repository"
  type        = string
  default     = "AES256"
}

variable "kms_key" {
  description = "The KMS key to use for encryption when encryption_type is KMS"
  type        = string
  default     = null
}

variable "lifecycle_policy" {
  description = "Lifecycle policy for the ECR repository"
  type        = string
  default     = null
}
