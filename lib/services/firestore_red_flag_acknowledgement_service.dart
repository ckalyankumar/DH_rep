import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firestore storage for red flag acknowledgements.
///
/// Path: users/{userId}/redFlagAcknowledgements/{docId}
/// Doc: { flagType, timestamp, acknowledgedAt, actionConfirmed, urgency }
class FirestoreRedFlagAcknowledgementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _userId;

  FirestoreRedFlagAcknowledgementService({String? userId})
      : _userId = userId ?? FirebaseAuth.instance.currentUser?.uid;

  String? get _effectiveUserId => _userId ?? FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col {
    final uid = _effectiveUserId;
    if (uid == null) throw StateError('No userId for red flag acknowledgement');
    return _db.collection('users').doc(uid).collection('redFlagAcknowledgements');
  }

  /// Log a RedFlagAcknowledgement event.
  Future<void> logAcknowledgement({
    required String flagType,
    required DateTime timestamp,
    required bool actionConfirmed,
    required String urgency,
  }) async {
    if (_effectiveUserId == null) return;
    try {
      await _col.add({
        'flagType': flagType,
        'timestamp': timestamp.toIso8601String(),
        'acknowledgedAt': DateTime.now().toIso8601String(),
        'actionConfirmed': actionConfirmed,
        'urgency': urgency,
      });
    } catch (e) {
      debugPrint('❌ FirestoreRedFlagAcknowledgementService ERROR: $e');
      rethrow;
    }
  }

  /// Check if an urgent flag has been acknowledged (action logged) in the last 7 days.
  Future<bool> hasUrgentFlagBeenAcknowledged(String flagType) async {
    if (_effectiveUserId == null) return false;
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _col
          .where('flagType', isEqualTo: flagType)
          .where('urgency', isEqualTo: 'urgent')
          .where('acknowledgedAt', isGreaterThanOrEqualTo: cutoff.toIso8601String())
          .where('actionConfirmed', isEqualTo: true)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ hasUrgentFlagBeenAcknowledged ERROR: $e');
      return false;
    }
  }

  /// For multiple urgent flags, return which have NOT been acknowledged.
  Future<List<String>> filterUnacknowledgedUrgentFlags(
    List<String> flagTypes,
  ) async {
    final unack = <String>[];
    for (final ft in flagTypes) {
      final acked = await hasUrgentFlagBeenAcknowledged(ft);
      if (!acked) unack.add(ft);
    }
    return unack;
  }
}
