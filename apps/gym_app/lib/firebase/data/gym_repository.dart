import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';
import 'package:gym_core/gym_core.dart';
import 'package:intl/intl.dart';

class GymRepository {
  GymRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : firestore = firestore ?? FirebaseFirestore.instance,
      functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  Stream<DocumentSnapshot<Map<String, dynamic>>> fitnessProfile(
    FitnessScope scope,
  ) => firestore.doc(scope.profilePath).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> fitnessRecords(
    FitnessScope scope,
    String collection, {
    int limit = 30,
  }) {
    Query<Map<String, dynamic>> query = firestore.collection(
      scope.collectionPath(collection),
    );
    if (!scope.isPersonal) {
      query = query.where('memberUid', isEqualTo: scope.uid);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> fitnessProgressPhotos(
    FitnessScope scope, {
    int limit = 24,
  }) => fitnessRecords(scope, 'progress_photos', limit: limit);

  Stream<QuerySnapshot<Map<String, dynamic>>> fitnessRoutines(
    FitnessScope scope, {
    int limit = 30,
  }) => fitnessRecords(scope, 'routines', limit: limit);

  Stream<QuerySnapshot<Map<String, dynamic>>> tenantExercises(
    String gymId, {
    int limit = 100,
  }) => firestore.collection('gyms/$gymId/exercises').limit(limit).snapshots();

  Future<Map<String, dynamic>?> previousExerciseSet(
    FitnessScope scope,
    String exerciseId,
  ) async => (await previousExerciseSets(scope, [exerciseId]))[exerciseId];

  /// Resolves the most recently completed set for each of [exerciseIds] in
  /// one query, instead of one query per exercise (avoids N+1 reads when a
  /// routine has several movements).
  Future<Map<String, Map<String, dynamic>?>> previousExerciseSets(
    FitnessScope scope,
    Iterable<String> exerciseIds,
  ) async {
    Query<Map<String, dynamic>> query = firestore.collection(
      scope.collectionPath('workout_logs'),
    );
    if (!scope.isPersonal) {
      query = query.where('memberUid', isEqualTo: scope.uid);
    }
    final snapshot = await query
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    final remaining = exerciseIds.toSet();
    final results = <String, Map<String, dynamic>?>{
      for (final id in remaining) id: null,
    };
    for (final document in snapshot.docs) {
      if (remaining.isEmpty) break;
      final exercises = document.data()['exercises'] as List? ?? const [];
      for (final raw in exercises.whereType<Map>()) {
        final exercise = Map<String, dynamic>.from(raw);
        final matchedId = remaining.firstWhere(
          (id) => exercise['exerciseId'] == id || exercise['movementId'] == id,
          orElse: () => '',
        );
        if (matchedId.isEmpty) continue;
        final sets = exercise['sets'] as List? ?? const [];
        final completed = sets.whereType<Map>().toList();
        if (completed.isNotEmpty) {
          results[matchedId] = Map<String, dynamic>.from(completed.last);
          remaining.remove(matchedId);
        }
      }
    }
    return results;
  }

  Future<void> saveFitnessRecord({
    required FitnessScope scope,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    await _requireOnline();
    await firestore.collection(scope.collectionPath(collection)).add({
      ...data,
      if (!scope.isPersonal) ...{
        'gymId': scope.gymId,
        'memberUid': scope.uid,
      } else ...{
        'ownerUid': scope.uid,
        'origin': data['origin'] ?? 'personal',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (scope.isPersonal) {
      final milestone = collection == 'workout_logs'
          ? 'firstWorkout'
          : collection == 'measurements' || collection == 'goals'
          ? 'firstProgress'
          : null;
      if (milestone != null) {
        unawaited(trackPersonalFeatureUsage(milestone).catchError((_) {}));
      }
    }
  }

  Future<void> updateFitnessRecord({
    required FitnessScope scope,
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await _requireOnline();
    await firestore.doc('${scope.collectionPath(collection)}/$id').update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFitnessRoutine({
    required FitnessScope scope,
    String? routineId,
    required String name,
    required List<int> scheduledWeekdays,
    required List<Map<String, dynamic>> movements,
  }) async {
    await _requireOnline();
    final data = <String, dynamic>{
      if (!scope.isPersonal) ...{
        'gymId': scope.gymId,
        'memberUid': scope.uid,
      } else ...{
        'ownerUid': scope.uid,
        'origin': 'personal',
      },
      'name': name.trim(),
      'scheduledWeekdays': scheduledWeekdays,
      'movements': movements,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final collection = firestore.collection(scope.collectionPath('routines'));
    if (routineId == null) {
      await collection.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await collection.doc(routineId).update(data);
    }
    if (scope.isPersonal) {
      unawaited(trackPersonalFeatureUsage('firstRoutine').catchError((_) {}));
    }
  }

  Future<void> deleteFitnessRoutine({
    required FitnessScope scope,
    required String routineId,
  }) async {
    await _requireOnline();
    await firestore
        .doc('${scope.collectionPath('routines')}/$routineId')
        .delete();
  }

  Future<void> updateFitnessProfile({
    required FitnessScope scope,
    required Map<String, dynamic> data,
  }) async {
    await _requireOnline();
    await firestore.doc(scope.profilePath).set({
      ...data,
      if (scope.isPersonal) 'ownerUid': scope.uid,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> gymSharing(
    String uid,
    String gymId,
  ) => firestore.doc('users/$uid/gym_shares/$gymId').snapshots();

  Future<void> updateGymSharing({
    required String gymId,
    required Map<String, bool> categories,
  }) => functions.httpsCallable('updateGymSharing').call<void>({
    'gymId': gymId,
    'categories': categories,
  });

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
    'scopeType': 'gym',
    'gymId': gymId,
    'featureId': featureId,
  });

  Future<void> trackPersonalFeatureUsage(String featureId) =>
      functions.httpsCallable('trackFeatureUsage').call<void>({
        'scopeType': 'personal',
        'audience': 'standalone',
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

  Stream<QuerySnapshot<Map<String, dynamic>>> memberProgressPhotos(
    String gymId,
    String uid, {
    int limit = 24,
  }) => firestore
      .collection('gyms/$gymId/progress_photos')
      .where('memberUid', isEqualTo: uid)
      .limit(limit)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> memberRoutines(
    String gymId,
    String uid, {
    int limit = 30,
  }) => firestore
      .collection('gyms/$gymId/member_routines')
      .where('memberUid', isEqualTo: uid)
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

  Future<void> correctAttendance({
    required String gymId,
    required String memberUid,
    required DateTime date,
    required bool present,
    required String reason,
  }) => functions.httpsCallable('correctAttendance').call<void>({
    'gymId': gymId,
    'memberUid': memberUid,
    'dateKey': DateFormat('yyyy-MM-dd').format(date),
    'present': present,
    'reason': reason.trim(),
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> attendanceHistory(
    String gymId, {
    String? memberUid,
    int limit = 30,
  }) {
    Query<Map<String, dynamic>> query = firestore.collection(
      'gyms/$gymId/attendance',
    );
    if (memberUid != null) {
      query = query.where('memberUid', isEqualTo: memberUid);
    }
    return query
        .orderBy('checkedInAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> scheduledClasses(
    String gymId, {
    int limit = 50,
  }) => firestore
      .collection('gyms/$gymId/class_sessions')
      .where('status', isEqualTo: 'scheduled')
      .orderBy('startsAt')
      .limit(limit)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> memberClassBookings(
    String gymId,
    String uid, {
    int limit = 50,
  }) => firestore
      .collection('gyms/$gymId/class_bookings')
      .where('memberUid', isEqualTo: uid)
      .limit(limit)
      .snapshots();

  Future<Map<String, String>> memberDisplayNames(
    String gymId,
    Iterable<String> memberUids,
  ) async {
    final unique = memberUids.toSet().take(30).toList(growable: false);
    final snapshots = await Future.wait(
      unique.map((uid) => firestore.doc('gyms/$gymId/members/$uid').get()),
    );
    return {
      for (var index = 0; index < unique.length; index++)
        unique[index]: _memberDisplayName(
          snapshots[index].data(),
          unique[index],
        ),
    };
  }

  String _memberDisplayName(Map<String, dynamic>? data, String uid) {
    for (final key in ['displayName', 'email', 'phone']) {
      final value = data?[key] as String?;
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return uid.length <= 8 ? uid : '${uid.substring(0, 8)}…';
  }

  Future<void> bookClass({required String gymId, required String sessionId}) =>
      functions.httpsCallable('bookClass').call<void>({
        'gymId': gymId,
        'sessionId': sessionId,
      });

  Future<void> cancelClassBooking({
    required String gymId,
    required String sessionId,
  }) => functions.httpsCallable('cancelClassBooking').call<void>({
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

  Future<void> saveMemberRoutine({
    required String gymId,
    required String uid,
    String? routineId,
    required String name,
    required List<int> scheduledWeekdays,
    required List<Map<String, dynamic>> movements,
  }) async {
    await _requireOnline();
    final data = <String, dynamic>{
      'gymId': gymId,
      'memberUid': uid,
      'name': name.trim(),
      'scheduledWeekdays': scheduledWeekdays,
      'movements': movements,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (routineId == null) {
      await firestore.collection('gyms/$gymId/member_routines').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await firestore
          .doc('gyms/$gymId/member_routines/$routineId')
          .update(data);
    }
  }

  Future<void> deleteMemberRoutine({
    required String gymId,
    required String routineId,
  }) async {
    await _requireOnline();
    await firestore.doc('gyms/$gymId/member_routines/$routineId').delete();
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
