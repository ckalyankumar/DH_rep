import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:dhealth/models/pro_assessment.dart';

/// Firestore storage for validated PRO questionnaires (POEM, DLQI, etc.).
///
/// Path: `users/{userId}/proAssessments/{assessmentId}`
class FirestoreProAssessmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  FirestoreProAssessmentService({required this.userId});

  String get _effectiveUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? userId;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection('users')
      .doc(_effectiveUserId)
      .collection('proAssessments');

  Future<void> saveAssessment(ProAssessment assessment) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint(
        '❌ FirestoreProAssessmentService.saveAssessment: no authenticated user',
      );
      return;
    }

    await _col.doc(assessment.id).set(
          assessment.toJson(),
          SetOptions(merge: true),
        );
  }

  /// Return the latest assessment for a given type/condition, or null.
  Future<ProAssessment?> getLatestForType({
    required String type,
    required String condition,
  }) async {
    try {
      final snap = await _col
          .where('type', isEqualTo: type)
          .where('condition', isEqualTo: condition)
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return ProAssessment.fromJson(doc.data(), id: doc.id);
    } catch (e) {
      debugPrint('❌ FirestoreProAssessmentService.getLatestForType ERROR: $e');
      return null;
    }
  }

  /// Get assessments over the last [days] days for a given type/condition.
  Future<List<ProAssessment>> getAssessments({
    required String type,
    required String condition,
    required int days,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final snap = await _col
          .where('type', isEqualTo: type)
          .where('condition', isEqualTo: condition)
          .where('date', isGreaterThanOrEqualTo: cutoff.toIso8601String())
          .orderBy('date', descending: false)
          .get();

      return snap.docs
          .map((d) => ProAssessment.fromJson(d.data(), id: d.id))
          .toList();
    } catch (e) {
      debugPrint('❌ FirestoreProAssessmentService.getAssessments ERROR: $e');
      return [];
    }
  }

  /// Check if there is an assessment for the current week for a given type/condition.
  ///
  /// Weeks are computed using Sunday as week start (matching WeeklySelfEfficacyPulse).
  Future<bool> hasAssessmentForCurrentWeek({
    required String type,
    required String condition,
  }) async {
    try {
      final now = DateTime.now();
      final weekday = now.weekday; // 1=Mon, 7=Sun
      final daysFromSunday = weekday == 7 ? 0 : weekday;
      final weekStart =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: daysFromSunday));
      final snap = await _col
          .where('type', isEqualTo: type)
          .where('condition', isEqualTo: condition)
          .where('date', isGreaterThanOrEqualTo: weekStart.toIso8601String())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ FirestoreProAssessmentService.hasAssessmentForCurrentWeek ERROR: $e');
      return false;
    }
  }
}

