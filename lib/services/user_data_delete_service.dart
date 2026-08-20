import 'package:cloud_firestore/cloud_firestore.dart';

/// Deletes all user data from Firestore (subcollections + user doc).
/// Used for account deletion.
class UserDataDeleteService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> _topLevelCollections = [
    'dailyLogs',
    'weeklyPulses',
    'proAssessments',
    'reports',
    'wearableSources',
    'dailyWearableAggregates',
    'syncAuditLog',
    'redFlagAcknowledgements',
    'flareEvents',
    'flareCandidates',
    'medicationExceptions',
  ];

  /// Delete all documents in a collection (no nested subcollections).
  static Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
    const batchSize = 100;
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await col.limit(batchSize).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } while (snapshot.docs.length >= batchSize);
  }

  /// Delete sharedWithDoctors docs and their nested doctorSession, clinicalMessages.
  static Future<void> _deleteSharedWithDoctors(DocumentReference<Map<String, dynamic>> userDoc) async {
    final sharedCol = userDoc.collection('sharedWithDoctors');
    final snapshot = await sharedCol.get();
    for (final doc in snapshot.docs) {
      final sessionSnap = await doc.reference.collection('doctorSession').get();
      for (final d in sessionSnap.docs) {
        await d.reference.delete();
      }
      final msgSnap = await doc.reference.collection('clinicalMessages').get();
      for (final d in msgSnap.docs) {
        await d.reference.delete();
      }
      await doc.reference.delete();
    }
  }

  /// Delete all data for user [uid]. Call before FirebaseAuth delete.
  static Future<void> deleteAllUserData(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    for (final name in _topLevelCollections) {
      await _deleteCollection(userRef.collection(name));
    }
    await _deleteSharedWithDoctors(userRef);
    await userRef.delete();
  }
}
