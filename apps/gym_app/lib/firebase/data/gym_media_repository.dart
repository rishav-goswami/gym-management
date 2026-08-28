import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class GymMediaRepository {
  GymMediaRepository({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    ImagePicker? picker,
  }) : storage = storage ?? FirebaseStorage.instance,
       firestore = firestore ?? FirebaseFirestore.instance,
       picker = picker ?? ImagePicker();

  final FirebaseStorage storage;
  final FirebaseFirestore firestore;
  final ImagePicker picker;

  Future<String?> pickAndUploadGymLogo({required String gymId}) async {
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
    final reference = storage.ref(
      'gyms/$gymId/branding/logo-${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=86400',
      ),
    );
    return reference.getDownloadURL();
  }

  Future<String?> pickAndUploadProgressPhoto({
    required String gymId,
    required String uid,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final path =
        'gyms/$gymId/progress/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    await firestore.collection('gyms/$gymId/progress_photos').add({
      'gymId': gymId,
      'memberUid': uid,
      'storagePath': path,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return path;
  }

  Future<String?> pickAndUploadProfilePhoto({
    required String gymId,
    required String uid,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError('Profile image must be smaller than 10 MB.');
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
        'gyms/$gymId/profiles/$uid/avatar-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await storage
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
            cacheControl: 'private,max-age=3600',
          ),
        );
    return path;
  }

  /// Reads through the authenticated SDK; no permanent public download URL is created.
  Future<Uint8List?> readPrivatePhoto(
    String storagePath, {
    int maxBytes = 10 * 1024 * 1024,
  }) => storage.ref(storagePath).getData(maxBytes);
}
