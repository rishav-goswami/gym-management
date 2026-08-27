locals {
  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "eventarc.googleapis.com",
    "fcm.googleapis.com",
    "firebase.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebasehosting.googleapis.com",
    "firebaseremoteconfig.googleapis.com",
    "firebaserules.googleapis.com",
    "firestore.googleapis.com",
    "identitytoolkit.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project" "default" {
  provider = google-beta.bootstrap

  project_id      = var.project_id
  name            = var.project_name
  billing_account = var.billing_account
  folder_id       = var.folder_id

  deletion_policy = "PREVENT"
}

resource "google_project_service" "required" {
  provider = google-beta.bootstrap
  for_each = local.required_services

  project            = google_project.default.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = google_project.default.project_id

  depends_on = [google_project_service.required]
}

resource "google_firestore_database" "default" {
  provider = google-beta
  project  = google_firebase_project.default.project

  name                              = "(default)"
  location_id                       = var.firestore_location
  type                              = "FIRESTORE_NATIVE"
  database_edition                  = "STANDARD"
  delete_protection_state           = "DELETE_PROTECTION_ENABLED"
  point_in_time_recovery_enablement = var.enable_point_in_time_recovery ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  deletion_policy                   = "ABANDON"
}

resource "google_identity_platform_config" "default" {
  provider = google-beta
  project  = google_firebase_project.default.project

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = true
      password_required = true
    }

    phone_number {
      enabled = var.enable_phone_auth
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_firebase_android_app" "gym_app" {
  provider = google-beta
  project  = google_firebase_project.default.project

  display_name    = "Gym Management Android"
  package_name    = var.android_package_name
  deletion_policy = "ABANDON"
}

resource "google_firebase_apple_app" "gym_app" {
  provider = google-beta
  project  = google_firebase_project.default.project

  display_name    = "Gym Management Apple"
  bundle_id       = var.apple_bundle_id
  deletion_policy = "ABANDON"
}

resource "google_firebase_web_app" "gym_app" {
  provider = google-beta
  project  = google_firebase_project.default.project

  display_name    = "Gym Management Customer Web"
  deletion_policy = "ABANDON"
}

resource "google_firebase_web_app" "platform_console" {
  provider = google-beta
  project  = google_firebase_project.default.project

  display_name    = "Gym Management Platform Console"
  deletion_policy = "ABANDON"
}

resource "google_firebase_hosting_site" "gym_app" {
  provider = google-beta
  project  = google_firebase_project.default.project

  site_id         = var.gym_app_site_id
  app_id          = google_firebase_web_app.gym_app.app_id
  deletion_policy = "ABANDON"
}

resource "google_firebase_hosting_site" "platform_console" {
  provider = google-beta
  project  = google_firebase_project.default.project

  site_id         = var.platform_console_site_id
  app_id          = google_firebase_web_app.platform_console.app_id
  deletion_policy = "ABANDON"
}

resource "google_firestore_backup_schedule" "daily" {
  provider = google-beta
  count    = var.enable_daily_backups ? 1 : 0
  project  = google_firebase_project.default.project
  database = google_firestore_database.default.name

  retention = var.backup_retention
  daily_recurrence {}
}
