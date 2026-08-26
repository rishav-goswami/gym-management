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

  /// Reads through the authenticated SDK; no permanent public download URL is created.
  Future<Uint8List?> readPrivatePhoto(
    String storagePath, {
    int maxBytes = 10 * 1024 * 1024,
  }) => storage.ref(storagePath).getData(maxBytes);
}
