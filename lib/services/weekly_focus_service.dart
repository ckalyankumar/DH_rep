import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/weekly_focus.dart';

class WeeklyFocusOutcomeResult {
  final bool improved;
  final String metricLabel;
  final double beforeAvg;
  final double afterAvg;

  const WeeklyFocusOutcomeResult({
    required this.improved,
    required this.metricLabel,
    required this.beforeAvg,
    required this.afterAvg,
  });
}

class WeeklyFocusService {
  WeeklyFocusService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Firestore path: users/{uid}/weeklyFocus/{id}
  CollectionReference<Map<String, dynamic>> _focusCollection(String uid) {
    return _db.collection('users').doc(uid).collection('weeklyFocus');
  }

  /// Save a weekly focus entry (accepted, declined, or patient-entered).
  Future<void> saveFocus(WeeklyFocus focus) async {
    await _focusCollection(focus.uid)
        .doc(focus.id)
        .set(focus.toJson(), SetOptions(merge: true));
  }

  /// Get the focus entry for the current week, if any.
  /// Current week = the Monday on or before DateTime.now().
  Future<WeeklyFocus?> getFocusForCurrentWeek(
    String uid,
    String condition,
  ) async {
    final weekStart = WeeklyFocus.currentWeekStart();
    final weekStartIso = weekStart.toIso8601String();

    try {
      final snap = await _focusCollection(uid)
          .where('weekStartDate', isEqualTo: weekStartIso)
          .orderBy('createdAt', descending: true)
          .get();

      if (snap.docs.isEmpty) return null;

      for (final doc in snap.docs) {
        final data = doc.data();
        if ((data['condition'] as String?) == condition) {
          return WeeklyFocus.fromJson(data, id: doc.id);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get all focus entries for a user, sorted by weekStartDate descending.
  Future<List<WeeklyFocus>> getAllFocus(String uid) async {
    try {
      final snap = await _focusCollection(uid)
          .orderBy('weekStartDate', descending: true)
          .get();
      return snap.docs
          .map((doc) => WeeklyFocus.fromJson(doc.data(), id: doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Passive outcome evaluation for a single weekly focus.
  ///
  /// Returns null when:
  /// - focus.outcome is not accepted
  /// - triggerCategory is null
  /// - either window has fewer than 5 logs
  WeeklyFocusOutcomeResult? evaluateOutcome({
    required WeeklyFocus focus,
    required List<DailyLog> logsAfterFocus,
    required List<DailyLog> logsBeforeFocus,
  }) {
    if (focus.outcome != WeeklyFocusOutcome.accepted) return null;
    if (focus.triggerCategory == null) return null;
    if (logsBeforeFocus.length < 5 || logsAfterFocus.length < 5) return null;

    final category = focus.triggerCategory!.toLowerCase();

    String metricLabel;
    bool lowerIsBetter;
    double Function(DailyLog) selector;

    switch (category) {
      case 'stress':
        metricLabel = 'Stress level (0–10)';
        lowerIsBetter = true;
        selector = (log) => log.stressLevel.toDouble();
        break;
      case 'sleep':
        metricLabel = 'Sleep quality (1–5)';
        lowerIsBetter = false;
        selector = (log) => log.sleepQuality.toDouble();
        break;
      case 'diet':
      case 'environment':
      case 'general':
        metricLabel = 'Itch intensity (0–10)';
        lowerIsBetter = true;
        selector = (log) => log.itchIntensity.toDouble();
        break;
      default:
        return null;
    }

    double avg(List<DailyLog> logs) {
      if (logs.isEmpty) return 0;
      final total = logs.fold<double>(0, (acc, log) => acc + selector(log));
      return total / logs.length;
    }

    final beforeAvg = avg(logsBeforeFocus);
    final afterAvg = avg(logsAfterFocus);

    bool improved;
    if (lowerIsBetter) {
      improved = (beforeAvg - afterAvg) >= 0.5;
    } else {
      improved = (afterAvg - beforeAvg) >= 0.5;
    }

    return WeeklyFocusOutcomeResult(
      improved: improved,
      metricLabel: metricLabel,
      beforeAvg: beforeAvg,
      afterAvg: afterAvg,
    );
  }
}

