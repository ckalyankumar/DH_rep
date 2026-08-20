import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';

/// Firestore: users/{userId}/weeklyPulses/{weekId}
class FirestoreWeeklyPulseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  FirestoreWeeklyPulseService({required this.userId});

  String get _effectiveUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? userId;

  CollectionReference<Map<String, dynamic>> get _pulsesCol =>
      _db.collection('users').doc(_effectiveUserId).collection('weeklyPulses');

  /// Save pulse for current week (overwrites if exists)
  Future<void> savePulse(WeeklySelfEfficacyPulse pulse) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final weekId = WeeklySelfEfficacyPulse.weekIdFromDate(pulse.weekStartDate);
    await _pulsesCol.doc(weekId).set(pulse.toJson(), SetOptions(merge: true));
  }

  /// Get pulse for a specific week
  Future<WeeklySelfEfficacyPulse?> getPulseForWeek(DateTime weekStart) async {
    final weekId = WeeklySelfEfficacyPulse.weekIdFromDate(weekStart);
    final doc = await _pulsesCol.doc(weekId).get();
    if (!doc.exists || doc.data() == null) return null;
    return WeeklySelfEfficacyPulse.fromJson(doc.data()!, id: doc.id);
  }

  /// Check if current week's pulse has been submitted
  Future<bool> hasPulseForCurrentWeek() async {
    final weekStart = WeeklySelfEfficacyPulse.getWeekStart(DateTime.now());
    final pulse = await getPulseForWeek(weekStart);
    return pulse != null;
  }

  /// Get pulses for last N weeks (for reports)
  Future<List<WeeklySelfEfficacyPulse>> getPulsesForLastWeeks(int weeks) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: weeks * 7));
      final snap = await _pulsesCol
          .where('weekStartDate', isGreaterThanOrEqualTo: cutoff.toIso8601String())
          .orderBy('weekStartDate', descending: false)
          .get();

      return snap.docs
          .map((d) => WeeklySelfEfficacyPulse.fromJson(d.data(), id: d.id))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
