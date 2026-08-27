import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';

class GymRepository {
  GymRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : firestore = firestore ?? FirebaseFirestore.instance,
      functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  Stream<DocumentSnapshot<Map<String, dynamic>>> platformSubscription(
    String gymId,
  ) => firestore.doc('gyms/$gymId/platform_subscription/current').snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> usage(String gymId) =>
      firestore.doc('gyms/$gymId/usage/current').snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> memberProfile(
    String gymId,
    String uid,
  ) => firestore.doc('gyms/$gymId/members/$uid').snapshots();

  Future<void> updateMemberProfile({
    required String gymId,
    required String uid,
    required String displayName,
    required String experienceLevel,
    required List<String> fitnessGoals,
    required int workoutDaysPerWeek,
    required List<String> equipmentAccess,
    double? heightCm,
    double? weightKg,
    String? phone,
    String? gender,
    String? limitations,
    String? photoPath,
  }) => firestore.doc('gyms/$gymId/members/$uid').update({
    'displayName': displayName.trim(),
    'experienceLevel': experienceLevel,
    'fitnessGoals': fitnessGoals,
    'workoutDaysPerWeek': workoutDaysPerWeek,
    'equipmentAccess': equipmentAccess,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'phone': _nullable(phone),
    'gender': _nullable(gender),
    'limitations': _nullable(limitations),
    if (photoPath != null) 'photoPath': photoPath,
    'onboardingCompletedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> trackFeatureUsage({
    required String gymId,
    required String featureId,
  }) => functions.httpsCallable('trackFeatureUsage').call<void>({
    'gymId': gymId,
    'featureId': featureId,
  });

  Future<void> submitFeatureFeedback({
    required String gymId,
    required String featureId,
    required int rating,
    required String message,
  }) => functions.httpsCallable('submitFeatureFeedback').call<void>({
    'gymId': gymId,
    'featureId': featureId,
    'rating': rating,
    'message': message.trim(),
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> publicSaasPlans() => firestore
      .collection('saas_plans')
      .where('status', isEqualTo: 'active')
      .where('isPublic', isEqualTo: true)
      .snapshots();

  Future<Map<String, dynamic>> startGymTrial({
    required String name,
    String? phone,
    String? city,
  }) async => Map<String, dynamic>.from(
    (await functions.httpsCallable('startGymTrial').call({
          'name': name.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
          'currency': 'INR',
          'timezone': 'Asia/Kolkata',
          'locale': 'en-IN',
        })).data
        as Map,
  );

  Future<void> requestPlatformUpgrade({
    required String gymId,
    required String planId,
    String? note,
  }) => functions.httpsCallable('requestPlatformUpgrade').call<void>({
    'gymId': gymId,
    'planId': planId,
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
  });

  Stream<Map<String, dynamic>> dashboard(String gymId) => firestore
      .doc('gyms/$gymId/dashboard_metrics/current')
      .snapshots()
      .map((snapshot) => snapshot.data() ?? const {});

  Stream<QuerySnapshot<Map<String, dynamic>>> membershipPlans(String gymId) =>
      firestore
          .collection('gyms/$gymId/membership_plans')
          .orderBy('name')
          .limit(100)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> subscriptions(String gymId) =>
      firestore
          .collection('gyms/$gymId/subscriptions')
          .orderBy('endAt')
          .limit(250)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> payments(String gymId) =>
      firestore
          .collection('gyms/$gymId/payments')
          .orderBy('paidAt', descending: true)
          .limit(250)
          .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> memberSubscription(
    String gymId,
    String uid,
  ) => firestore.doc('gyms/$gymId/subscriptions/$uid').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> memberPayments(
    String gymId,
    String uid,
  ) => firestore
      .collection('gyms/$gymId/payments')
      .where('memberUid', isEqualTo: uid)
      .orderBy('paidAt', descending: true)
      .limit(50)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> notifications(
    String gymId,
    String uid,
  ) => firestore
      .collection('gyms/$gymId/notifications')
      .where('recipientUid', isEqualTo: uid)
      .limit(50)
      .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> renewalRequest(
    String gymId,
    String uid,
  ) => firestore.doc('gyms/$gymId/renewal_requests/$uid').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> renewalRequests(String gymId) =>
      firestore
          .collection('gyms/$gymId/renewal_requests')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();

  Future<void> markNotificationRead({
    required String gymId,
    required String notificationId,
  }) => firestore.doc('gyms/$gymId/notifications/$notificationId').update({
    'read': true,
    'readAt': FieldValue.serverTimestamp(),
  });

  Future<void> requestMembershipRenewal({
    required String gymId,
    required String planId,
  }) => functions.httpsCallable('requestMembershipRenewal').call<void>({
    'gymId': gymId,
    'planId': planId,
  });

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> activeMembers(
    String gymId,
  ) async =>
      (await firestore
              .collection('gyms/$gymId/members')
              .where('status', isEqualTo: 'active')
              .limit(250)
              .get())
          .docs;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> activePlans(
    String gymId,
  ) async =>
      (await firestore
              .collection('gyms/$gymId/membership_plans')
              .where('status', isEqualTo: 'active')
              .limit(100)
              .get())
          .docs;

  Stream<QuerySnapshot<Map<String, dynamic>>> recent(
    String gymId,
    String collection, {
    int limit = 30,
  }) => firestore
      .collection('gyms/$gymId/$collection')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> recentForMember(
    String gymId,
    String collection,
    String uid, {
    int limit = 30,
  }) => firestore
      .collection('gyms/$gymId/$collection')
      .where('memberUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();

  Future<Map<String, dynamic>> createInvitation({
    required String gymId,
    required String role,
    String? email,
    String? phone,
  }) async => Map<String, dynamic>.from(
    (await functions.httpsCallable('createInvitation').call({
          'gymId': gymId,
          'role': role,
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        })).data
        as Map,
  );

  Future<int> hydrateMemberProfiles(String gymId) async {
    final result = await functions.httpsCallable('hydrateMemberProfiles').call({
      'gymId': gymId,
    });
    return ((result.data as Map)['updated'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> createAttendanceQr(String gymId) async =>
      Map<String, dynamic>.from(
        (await functions.httpsCallable('createAttendanceQr').call({
              'gymId': gymId,
            })).data
            as Map,
      );

  Future<void> checkIn({required String gymId, required String token}) =>
      functions.httpsCallable('checkIn').call<void>({
        'gymId': gymId,
        'token': token,
      });

  Future<void> bookClass({required String gymId, required String sessionId}) =>
      functions.httpsCallable('bookClass').call<void>({
        'gymId': gymId,
        'sessionId': sessionId,
      });

  Future<void> createClassSession({
    required String gymId,
    required String name,
    required int capacity,
    required DateTime startsAt,
    String? trainerUid,
  }) => functions.httpsCallable('createClassSession').call<void>({
    'gymId': gymId,
    'name': name.trim(),
    'capacity': capacity,
    'startsAtMillis': startsAt.millisecondsSinceEpoch,
    if (trainerUid != null) 'trainerUid': trainerUid,
  });

  Future<void> updateConfiguration({
    required String gymId,
    required String name,
    required String currency,
    required String timezone,
    required String locale,
    required String primaryColor,
    required String secondaryColor,
    required String accentColor,
    required String tagline,
    String? logoUrl,
    String? phone,
    String? city,
    String? website,
  }) => functions.httpsCallable('updateGymConfiguration').call<void>({
    'gymId': gymId,
    'name': name,
    'currency': currency.toUpperCase(),
    'timezone': timezone,
    'locale': locale,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'accentColor': accentColor,
    'tagline': tagline,
    'logoUrl': logoUrl,
    'phone': _nullable(phone),
    'city': _nullable(city),
    'website': _nullable(website),
  });

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<Map<String, dynamic>> upsertMembershipPlan({
    required String gymId,
    String? planId,
    required String name,
    required String description,
    required int durationDays,
    required int priceMinor,
    required String status,
  }) async => Map<String, dynamic>.from(
    (await functions.httpsCallable('upsertMembershipPlan').call({
          'gymId': gymId,
          if (planId != null) 'planId': planId,
          'name': name,
          'description': description,
          'durationDays': durationDays,
          'priceMinor': priceMinor,
          'status': status,
        })).data
        as Map,
  );

  Future<Map<String, dynamic>> recordPayment({
    required String gymId,
    required String memberUid,
    required String planId,
    required int amountMinor,
    required String method,
    required DateTime startsAt,
    String? reference,
    String? notes,
  }) async => Map<String, dynamic>.from(
    (await functions.httpsCallable('recordPayment').call({
          'gymId': gymId,
          'memberUid': memberUid,
          'planId': planId,
          'amountMinor': amountMinor,
          'method': method,
          'paidAtMillis': DateTime.now().millisecondsSinceEpoch,
          'requestedStartMillis': startsAt.millisecondsSinceEpoch,
          if (reference != null && reference.trim().isNotEmpty)
            'reference': reference.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })).data
        as Map,
  );

  Future<String> createConversation({
    required String gymId,
    required String targetUid,
  }) async {
    final result = await functions.httpsCallable('createConversation').call({
      'gymId': gymId,
      'targetUid': targetUid,
    });
    return (result.data as Map)['conversationId'] as String;
  }

  Future<void> updateMembership({
    required String gymId,
    required String uid,
    required String role,
    required String status,
    Map<String, bool>? permissionOverrides,
  }) => functions.httpsCallable('updateGymMembership').call<void>({
    'gymId': gymId,
    'uid': uid,
    'role': role,
    'status': status,
    if (permissionOverrides != null) 'permissionOverrides': permissionOverrides,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(
    String gymId,
    String conversationId,
  ) => firestore
      .collection('gyms/$gymId/conversations/$conversationId/messages')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> conversations(
    String gymId,
    String uid,
  ) => firestore
      .collection('gyms/$gymId/conversations')
      .where('participantUids', arrayContains: uid)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots();

  Future<void> sendMessage({
    required String gymId,
    required String conversationId,
    required String senderUid,
    required String text,
  }) async {
    await _requireOnline();
    await firestore
        .collection('gyms/$gymId/conversations/$conversationId/messages')
        .add({
          'gymId': gymId,
          'senderUid': senderUid,
          'text': text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> saveMemberOwnedRecord({
    required String gymId,
    required String collection,
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _requireOnline();
    await firestore.collection('gyms/$gymId/$collection').add({
      ...data,
      'gymId': gymId,
      'memberUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createManagedRecord({
    required String gymId,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    await _requireOnline();
    await firestore.collection('gyms/$gymId/$collection').add({
      ...data,
      'gymId': gymId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> exportCsv({
    required String gymId,
    required String collection,
  }) async {
    const reportFields = <String, List<String>>{
      'members': ['uid', 'displayName', 'email', 'phone', 'status'],
      'attendance': ['memberUid', 'dateKey', 'source', 'checkedInAt'],
      'payments': [
        'receiptNumber',
        'memberUid',
        'memberName',
        'planId',
        'planName',
        'amountMinor',
        'currency',
        'method',
        'reference',
        'paidAt',
      ],
      'subscriptions': [
        'memberUid',
        'memberName',
        'planId',
        'planName',
        'status',
        'startAt',
        'endAt',
      ],
    };
    final fields = reportFields[collection];
    if (fields == null) throw ArgumentError('Unsupported report: $collection');
    final rows = <List<dynamic>>[fields];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    for (var page = 0; page < 20; page++) {
      Query<Map<String, dynamic>> query = firestore
          .collection('gyms/$gymId/$collection')
          .orderBy(FieldPath.documentId)
          .limit(500);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snapshot = await query.get();
      for (final document in snapshot.docs) {
        final data = document.data();
        rows.add(fields.map((field) => _csvValue(data[field])).toList());
      }
      if (snapshot.docs.length < 500) break;
      cursor = snapshot.docs.last;
    }
    return csv.encode(rows);
  }

  Object _csvValue(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    return value ?? '';
  }

  Future<void> _requireOnline() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      throw StateError(
        'Connect to the internet before saving. Cached plans remain available offline.',
      );
    }
  }
}
