import 'package:firebase_remote_config/firebase_remote_config.dart';

class AppFeatureFlags {
  const AppFeatureFlags._();

  static bool get chat => FirebaseRemoteConfig.instance.getBool('chat_enabled');
  static bool get attendanceQr =>
      FirebaseRemoteConfig.instance.getBool('attendance_qr_enabled');
  static bool get progressPhotos =>
      FirebaseRemoteConfig.instance.getBool('progress_photos_enabled');
  static String get maintenanceMessage =>
      FirebaseRemoteConfig.instance.getString('maintenance_message');
}
