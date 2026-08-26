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

  Stream<Map<String, dynamic>> dashboard(String gymId) => firestore
      .doc('gyms/$gymId/dashboard_metrics/current')
      .snapshots()
      .map((snapshot) => snapshot.data() ?? const {});

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

  Future<void> updateConfiguration({
    required String gymId,
    required String name,
    required String currency,
    required String timezone,
    required String locale,
    required String primaryColor,
    required Map<String, bool> features,
  }) => functions.httpsCallable('updateGymConfiguration').call<void>({
    'gymId': gymId,
    'name': name,
    'currency': currency.toUpperCase(),
    'timezone': timezone,
    'locale': locale,
    'primaryColor': primaryColor,
    'features': features,
  });

  Future<void> recordPayment({
    required String gymId,
    required String memberUid,
    required String planId,
    required int amountMinor,
    required String method,
    required DateTime startsAt,
    required DateTime endsAt,
  }) => functions.httpsCallable('recordPayment').call<void>({
    'gymId': gymId,
    'memberUid': memberUid,
    'planId': planId,
    'amountMinor': amountMinor,
    'method': method,
    'paidAtMillis': DateTime.now().millisecondsSinceEpoch,
    'startsAtMillis': startsAt.millisecondsSinceEpoch,
    'endsAtMillis': endsAt.millisecondsSinceEpoch,
  });

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
        'memberUid',
        'planId',
        'amountMinor',
        'currency',
        'method',
        'paidAt',
      ],
      'subscriptions': ['memberUid', 'planId', 'status', 'startAt', 'endAt'],
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
