import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class PlatformGymRepository {
  PlatformGymRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
       firestore = firestore ?? FirebaseFirestore.instance,
       storage = storage ?? FirebaseStorage.instance,
       picker = picker ?? ImagePicker() {
    // Register the browser implementation explicitly so an older cached web
    // bootstrap cannot leave the first upload on the method-channel fallback.
    if (kIsWeb && ImagePickerPlatform.instance is! ImagePickerPlugin) {
      ImagePickerPlatform.instance = ImagePickerPlugin();
    }
  }

  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImagePicker picker;

  Future<Map<String, dynamic>> loadDashboard() async =>
      Map<String, dynamic>.from(
        (await functions.httpsCallable('getPlatformDashboard').call()).data
            as Map,
      );

  Future<List<Map<String, dynamic>>> listConsumers({int limit = 100}) async {
    final response = await functions.httpsCallable('listConsumers').call({
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['consumers'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> setConsumerStatus({
    required String uid,
    required String status,
    required String reason,
  }) => functions.httpsCallable('setConsumerStatus').call<void>({
    'uid': uid,
    'status': status,
    'reason': reason,
  });

  Future<List<Map<String, dynamic>>> listSupportCases({int limit = 50}) async {
    final response = await functions.httpsCallable('listPlatformSupportCases').call({
      'limit': limit,
    });
    return (Map<String, dynamic>.from(response.data as Map)['cases'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> supportMessages(
    String targetUid,
    String caseId,
  ) => firestore
      .collection('users/$targetUid/support_cases/$caseId/messages')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  Future<String> createSupportCase({
    required String targetUid,
    required String category,
    required String subject,
    required String message,
    required String reason,
  }) async => (Map<String, dynamic>.from(
    (await functions.httpsCallable('createPlatformSupportCase').call({
      'targetUid': targetUid,
      'category': category,
      'subject': subject,
      'message': message,
      'reason': reason,
    })).data as Map,
  )['caseId'] as String);

  Future<void> replyToSupportCase({
    required String targetUid,
    required String caseId,
    required String message,
    String? attachmentPath,
  }) => functions.httpsCallable('sendSupportMessage').call<void>({
    'scopeType': 'platform',
    'targetUid': targetUid,
    'threadId': caseId,
    'text': message.trim(),
    'attachmentPath': ?attachmentPath,
  });

  Future<String?> pickAndUploadSupportImage({
    required String targetUid,
    required String caseId,
    ValueChanged<double>? onProgress,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kIsWeb ? null : 82,
      maxWidth: kIsWeb ? null : 1600,
      maxHeight: kIsWeb ? null : 1600,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes().timeout(const Duration(seconds: 20));
    if (bytes.length >= 5 * 1024 * 1024) {
      throw StateError('Support images must be smaller than 5 MB.');
    }
    final contentType = image.mimeType ?? 'image/jpeg';
    if (!const ['image/jpeg', 'image/png', 'image/webp'].contains(contentType)) {
      throw StateError('Use a JPEG, PNG, or WebP image.');
    }
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        'users/$targetUid/support/$caseId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final upload = storage.ref(path).putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'private,max-age=3600',
      ),
    );
    final progress = upload.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    try {
      await upload.timeout(const Duration(seconds: 60));
      onProgress?.call(1);
      return path;
    } finally {
      await progress.cancel();
    }
  }

  Future<String> supportImageUrl(String path) =>
      storage.ref(path).getDownloadURL();

  Future<void> resolveSupportCase({
    required String targetUid,
    required String caseId,
    required String status,
  }) => functions.httpsCallable('updateSupportThreadStatus').call<void>({
    'scopeType': 'platform',
    'targetUid': targetUid,
    'threadId': caseId,
    'status': status,
  });

  Future<Map<String, dynamic>> sendServiceNotice({
    required String audience,
    required String title,
    required String body,
  }) async => Map<String, dynamic>.from(
    (await functions.httpsCallable('sendPlatformServiceNotice').call({
      'audience': audience,
      'title': title.trim(),
      'body': body.trim(),
    })).data as Map,
  );

  Future<void> setConsumerEntitlementOverrides({
    required String uid,
    required Map<String, bool> overrides,
    required String reason,
  }) => functions.httpsCallable('setConsumerEntitlementOverrides').call<void>({
    'uid': uid,
    'overrides': overrides,
    'reason': reason,
  });

  Future<Map<String, dynamic>> openConsumerSupport({
    required String uid,
    required String reason,
    required List<String> categories,
  }) async {
    final grant = Map<String, dynamic>.from(
      (await functions.httpsCallable('startConsumerSupportSession').call({
            'targetUid': uid,
            'reason': reason,
            'categories': categories,
          })).data
          as Map,
    );
    return Map<String, dynamic>.from(
      (await functions.httpsCallable('getConsumerSupportData').call({
            'grantId': grant['grantId'],
            'targetUid': uid,
            'categories': categories,
          })).data
          as Map,
    );
  }

  Future<void> updatePlatformBranding(Map<String, dynamic> data) async {
    await functions
        .httpsCallable('updatePlatformBranding')
        .call<void>(data)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
            'Saving took too long. Check your connection and try again.',
          ),
        );
  }

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

  Future<String?> pickAndUploadPlatformImage({
    required String area,
    ValueChanged<double>? onProgress,
    ValueChanged<String>? onStage,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      // image_picker_for_web performs resizing through canvas.toBlob. That
      // callback can remain pending in some Chromium/mobile-emulation paths,
      // leaving the upload stuck before Firebase Storage is contacted. Upload
      // the original browser file and retain the size guard below instead.
      imageQuality: kIsWeb ? null : 85,
      maxWidth: kIsWeb ? null : 1600,
      maxHeight: kIsWeb ? null : 1600,
    );
    if (image == null) return null;
    onStage?.call('Reading image…');
    final bytes = await image.readAsBytes().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException(
        'The browser could not finish reading this image. Try a smaller JPEG or PNG.',
      ),
    );
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError('Image must be smaller than 10 MB.');
    }
    final contentType = image.mimeType?.startsWith('image/') == true
        ? image.mimeType!
        : 'image/jpeg';
    final extension = contentType == 'image/png' ? 'png' : 'jpg';
    final reference = storage.ref(
      'platform/$area/${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    onStage?.call('Starting secure upload…');
    final upload = reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        cacheControl: 'public,max-age=86400',
      ),
    );
    final progressSubscription = upload.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes <= 0) return;
      onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
    });
    try {
      await upload.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          unawaited(upload.cancel());
          throw TimeoutException(
            'The image upload took too long. Check your connection and retry.',
          );
        },
      );
      onProgress?.call(1);
    } finally {
      await progressSubscription.cancel();
    }
    onStage?.call('Finalizing image…');
    return reference.getDownloadURL().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException(
        'The image uploaded, but its download URL could not be confirmed. Retry shortly.',
      ),
    );
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
