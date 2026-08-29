import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:gym_core/gym_core.dart';
import 'package:image_picker/image_picker.dart';

class SupportRepository {
  SupportRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
       storage = storage ?? FirebaseStorage.instance,
       picker = picker ?? ImagePicker();

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseStorage storage;
  final ImagePicker picker;

  Stream<QuerySnapshot<Map<String, dynamic>>> inbox(String uid) => firestore
      .collection('users/$uid/support_inbox')
      .orderBy('lastMessageAt', descending: true)
      .limit(50)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> platformCases(String uid) =>
      firestore
          .collection('users/$uid/support_cases')
          .orderBy('lastMessageAt', descending: true)
          .limit(30)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> platformMessages(
    String uid,
    String caseId,
  ) => firestore
      .collection('users/$uid/support_cases/$caseId/messages')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> gymThreads(
    GymMembership membership,
  ) {
    Query<Map<String, dynamic>> query = firestore.collection(
      'gyms/${membership.gymId}/support_threads',
    );
    if (membership.role == GymRole.member) {
      query = query.where('memberUid', isEqualTo: membership.uid);
    } else {
      final categories = <String>[
        if (membership.can('support.coaching')) 'coaching',
        if (membership.can('support.billing')) 'payment',
        if (membership.can('support.manage')) ...[
          'membership',
          'attendance',
          'classes',
          'facility',
          'other',
        ],
      ];
      if (categories.isEmpty) {
        query = query.where('category', isEqualTo: '__none__');
      } else {
        // Keep the query constrained even when a role can handle every
        // category. Firestore rules evaluate queries against their possible
        // result set, so an unconstrained staff query is correctly rejected.
        query = query.where('category', whereIn: categories);
      }
    }
    return query
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> gymMessages(
    String gymId,
    String threadId,
  ) => firestore
      .collection('gyms/$gymId/support_threads/$threadId/messages')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> thread({
    required String scopeType,
    required String ownerUid,
    required String threadId,
    String? gymId,
    String? targetUid,
  }) {
    if (scopeType == 'gym') {
      if (gymId == null || gymId.isEmpty) {
        throw ArgumentError.value(gymId, 'gymId', 'Required for gym support');
      }
      return firestore.doc('gyms/$gymId/support_threads/$threadId').snapshots();
    }
    return firestore
        .doc('users/${targetUid ?? ownerUid}/support_cases/$threadId')
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> trainerAssignment(
    String gymId,
    String memberUid,
  ) => firestore.doc('gyms/$gymId/trainer_assignments/$memberUid').snapshots();

  Future<String> createPlatformCase({
    required String category,
    required String subject,
    required String message,
    Map<String, dynamic>? supportContext,
  }) async {
    final response = await functions.httpsCallable('createSupportThread').call({
      'scopeType': 'platform',
      'category': category,
      'subject': subject.trim(),
      'message': message.trim(),
      if (supportContext != null) 'context': supportContext,
    });
    return (response.data as Map)['threadId'] as String;
  }

  Future<String> createGymThread({
    required String gymId,
    required String category,
    required String subject,
    required String message,
    String? memberUid,
    String? reason,
    Map<String, dynamic>? supportContext,
  }) async {
    final response = await functions.httpsCallable('createSupportThread').call({
      'scopeType': 'gym',
      'gymId': gymId,
      'category': category,
      'subject': subject.trim(),
      'message': message.trim(),
      if (memberUid != null) 'memberUid': memberUid,
      if (reason != null) 'reason': reason.trim(),
      if (supportContext != null) 'context': supportContext,
    });
    return (response.data as Map)['threadId'] as String;
  }

  Future<void> sendMessage({
    required String scopeType,
    required String threadId,
    required String text,
    String? gymId,
    String? targetUid,
    String? attachmentPath,
  }) => functions.httpsCallable('sendSupportMessage').call<void>({
    'scopeType': scopeType,
    'threadId': threadId,
    'text': text.trim(),
    if (gymId != null) 'gymId': gymId,
    if (targetUid != null) 'targetUid': targetUid,
    if (attachmentPath != null) 'attachmentPath': attachmentPath,
  });

  Future<String?> pickAndUploadImage({
    required String scopeType,
    required String ownerId,
    required String threadId,
    ValueChanged<double>? onProgress,
  }) async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: kIsWeb ? null : 82,
      maxWidth: kIsWeb ? null : 1600,
      maxHeight: kIsWeb ? null : 1600,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    if (bytes.length >= 5 * 1024 * 1024) {
      throw StateError('Support images must be smaller than 5 MB.');
    }
    final mime = image.mimeType ?? 'image/jpeg';
    if (!const ['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
      throw StateError('Use a JPEG, PNG, or WebP image.');
    }
    final extension = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final prefix = scopeType == 'gym'
        ? 'gyms/$ownerId/support/$threadId'
        : 'users/$ownerId/support/$threadId';
    final path = '$prefix/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final upload = storage
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: mime,
            cacheControl: 'private,max-age=3600',
          ),
        );
    final subscription = upload.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    try {
      await upload;
      onProgress?.call(1);
      return path;
    } finally {
      await subscription.cancel();
    }
  }

  Future<String> imageUrl(String path) => storage.ref(path).getDownloadURL();

  Future<void> markRead({
    required String scopeType,
    required String threadId,
    String? gymId,
    String? targetUid,
  }) => functions.httpsCallable('markSupportThreadRead').call<void>({
    'scopeType': scopeType,
    'threadId': threadId,
    if (gymId != null) 'gymId': gymId,
    if (targetUid != null) 'targetUid': targetUid,
  });

  Future<void> updateStatus({
    required String scopeType,
    required String threadId,
    required String status,
    String? gymId,
    String? targetUid,
  }) => functions.httpsCallable('updateSupportThreadStatus').call<void>({
    'scopeType': scopeType,
    'threadId': threadId,
    'status': status,
    if (gymId != null) 'gymId': gymId,
    if (targetUid != null) 'targetUid': targetUid,
  });

  Future<void> submitResolutionRating({
    required String featureId,
    required int rating,
    String? gymId,
  }) => functions.httpsCallable('submitFeatureFeedback').call<void>({
    'scopeType': gymId == null ? 'personal' : 'gym',
    if (gymId != null) 'gymId': gymId,
    'featureId': featureId,
    'rating': rating,
    'message': 'Support resolution rating',
  });

  Future<void> claim({required String gymId, required String threadId}) =>
      functions.httpsCallable('claimGymSupportThread').call<void>({
        'gymId': gymId,
        'threadId': threadId,
      });

  Future<void> assignThread({
    required String gymId,
    required String threadId,
    required String assigneeUid,
  }) => functions.httpsCallable('assignGymSupportThread').call<void>({
    'gymId': gymId,
    'threadId': threadId,
    'assigneeUid': assigneeUid,
  });

  Future<void> assignPrimaryTrainer({
    required String gymId,
    required String memberUid,
    String? trainerUid,
  }) => functions.httpsCallable('assignPrimaryTrainer').call<void>({
    'gymId': gymId,
    'memberUid': memberUid,
    'trainerUid': trainerUid,
  });
}
