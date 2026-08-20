import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Persists PRO trajectory alert dismissals for engagement analysis.
///
/// Firestore path:
/// - users/{userId}/alertDismissals/{alertType}
///   Fields: alertType, dismissedAt, dismissCount
class ProAlertDismissalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) {
    return _db.collection('users').doc(userId).collection('alertDismissals');
  }

  /// Record a dismissal event for a given [alertType], e.g. 'proTrajectory'.
  Future<void> recordDismissal(String alertType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _col(user.uid).doc(alertType);
    final snap = await ref.get();
    final now = DateTime.now().toIso8601String();

    if (!snap.exists || snap.data() == null) {
      await ref.set({
        'alertType': alertType,
        'dismissedAt': now,
        'dismissCount': 1,
      });
      return;
    }

    final data = snap.data()!;
    final currentCount = (data['dismissCount'] as int?) ?? 0;
    await ref.update({
      'dismissedAt': now,
      'dismissCount': currentCount + 1,
    });
  }

  /// Get last dismissal timestamp (local DateTime) for [alertType], if any.
  Future<DateTime?> getLastDismissedAt(String alertType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snap = await _col(user.uid).doc(alertType).get();
    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    final ts = data['dismissedAt'];
    if (ts is String) {
      return DateTime.tryParse(ts);
    }
    return null;
  }
}

