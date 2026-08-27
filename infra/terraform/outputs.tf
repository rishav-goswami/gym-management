output "project_id" {
  value = google_firebase_project.default.project
}

output "firebase_app_ids" {
  value = {
    android          = google_firebase_android_app.gym_app.app_id
    apple            = google_firebase_apple_app.gym_app.app_id
    gym_web          = google_firebase_web_app.gym_app.app_id
    platform_console = google_firebase_web_app.platform_console.app_id
  }
}

output "hosting" {
  value = {
    gym_app = {
      site_id = google_firebase_hosting_site.gym_app.site_id
      url     = google_firebase_hosting_site.gym_app.default_url
    }
    platform_console = {
      site_id = google_firebase_hosting_site.platform_console.site_id
      url     = google_firebase_hosting_site.platform_console.default_url
    }
  }
}

output "post_apply_commands" {
  value = [
    "firebase target:apply hosting gym-app ${google_firebase_hosting_site.gym_app.site_id} --project ${google_firebase_project.default.project}",
    "firebase target:apply hosting platform-console ${google_firebase_hosting_site.platform_console.site_id} --project ${google_firebase_project.default.project}",
    "flutterfire configure --project=${google_firebase_project.default.project}",
  ]
}
