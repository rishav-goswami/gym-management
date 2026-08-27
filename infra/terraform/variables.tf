variable "project_id" {
  description = "Globally unique Google Cloud/Firebase project ID. Treat it as immutable."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid 6-30 character Google Cloud project ID."
  }
}

variable "project_name" {
  description = "Human-readable Google Cloud project name."
  type        = string
  default     = "Gym Management"
}

variable "billing_account" {
  description = "Cloud Billing account ID. Required for Blaze services and managed export/import."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "folder_id" {
  description = "Optional Google Cloud folder ID. Leave null for a personal project."
  type        = string
  default     = null
  nullable    = true
}

variable "firestore_location" {
  description = "Immutable location for the default Firestore database."
  type        = string
  default     = "asia-south1"
}

variable "android_package_name" {
  type    = string
  default = "com.rishva.gymmanagement"
}

variable "apple_bundle_id" {
  type    = string
  default = "com.rishva.gymmanagement"
}

variable "gym_app_site_id" {
  description = "Globally unique Firebase Hosting site ID for the customer app."
  type        = string
}

variable "platform_console_site_id" {
  description = "Globally unique Firebase Hosting site ID for the private platform console."
  type        = string
}

variable "enable_phone_auth" {
  description = "Enable Firebase phone-number sign-in. SMS region policy still needs review per environment."
  type        = bool
  default     = true
}

variable "enable_daily_backups" {
  description = "Create a paid daily Firestore backup schedule."
  type        = bool
  default     = false
}

variable "enable_point_in_time_recovery" {
  description = "Enable paid Firestore point-in-time recovery for production-like environments."
  type        = bool
  default     = false
}

variable "backup_retention" {
  description = "Firestore backup retention as a duration; maximum is 14 weeks."
  type        = string
  default     = "1209600s"
}
