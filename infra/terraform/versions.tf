terraform {
  required_version = ">= 1.6.0"

  backend "gcs" {}

  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.40"
    }
  }
}

provider "google-beta" {
  project               = var.project_id
  user_project_override = true
}

# Project creation cannot charge quota to a project that does not exist yet.
provider "google-beta" {
  alias                 = "bootstrap"
  user_project_override = false
}
