import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PlatformGymRepository {
  PlatformGymRepository({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
       storage = storage ?? FirebaseStorage.instance,
       picker = picker ?? ImagePicker();

  final FirebaseFunctions functions;
  final FirebaseStorage storage;
  final ImagePicker picker;

  Future<Map<String, dynamic>> loadDashboard() async =>
      Map<String, dynamic>.from(
        (await functions.httpsCallable('getPlatformDashboard').call()).data
            as Map,
      );

  Future<void> setSubscription({
    required String gymId,
    required String planId,
    required String status,
    required int durationDays,
    required Map<String, bool> featureOverrides,
  }) => functions.httpsCallable('setGymSubscription').call<void>({
    'gymId': gymId,
    'planId': planId,
    'status': status,
    'durationDays': durationDays,
    'featureOverrides': featureOverrides,
  });

  Future<String?> pickAndUploadLogo(String gymId) async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError('Logo must be smaller than 10 MB.');
    }
    final contentType = image.mimeType?.startsWith('image/') == true
        ? image.mimeType!
        : 'image/jpeg';
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        'gyms/$gymId/branding/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final reference = storage.ref(path);
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=86400',
      ),
    );
    return reference.getDownloadURL();
  }

  Future<void> updateConfiguration({
    required String gymId,
    required String name,
    required String tagline,
    required String primaryColor,
    required String secondaryColor,
    required String accentColor,
    required String currency,
    required String timezone,
    required String locale,
    String? logoUrl,
    String? phone,
    String? city,
    String? website,
  }) => functions.httpsCallable('updateGymAsPlatformAdmin').call<void>({
    'gymId': gymId,
    'name': name.trim(),
    'tagline': tagline.trim(),
    'primaryColor': primaryColor.trim(),
    'secondaryColor': secondaryColor.trim(),
    'accentColor': accentColor.trim(),
    'currency': currency.trim().toUpperCase(),
    'timezone': timezone.trim(),
    'locale': locale.trim(),
    'logoUrl': logoUrl,
    'phone': _nullable(phone),
    'city': _nullable(city),
    'website': _nullable(website),
  });

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
