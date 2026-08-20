import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:dhealth/models/user_report.dart';

/// Fetches and manages user report documents at Firestore path:
/// `/users/{userId}/reports`
class FirestoreReportsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  FirestoreReportsService({required this.userId});

  CollectionReference<Map<String, dynamic>> get _reportsCol =>
      _db.collection('users').doc(userId).collection('reports');

  /// Fetch all reports for the current user, newest first.
  Future<List<UserReport>> getReports() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint(
        '❌ FirestoreReportsService.getReports ERROR: no authenticated user',
      );
      return [];
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs
          .map((doc) => UserReport.fromJson(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ FirestoreReportsService.getReports ERROR: $e');
      return [];
    }
  }

  /// Stream of reports for the current user.
  Stream<List<UserReport>> reportsStream() {
    return _reportsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserReport.fromJson(doc.data(), id: doc.id))
            .toList());
  }

  /// Save a report document to users/{userId}/reports.
  Future<void> saveReport(UserReport report) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint(
        '❌ FirestoreReportsService.saveReport ERROR: no authenticated user',
      );
      return;
    }

    try {
      await _reportsCol
          .doc(report.id)
          .set(report.toJson(), SetOptions(merge: true));
      debugPrint('✅ Report saved to Firestore: ${report.id}');
    } catch (e) {
      debugPrint('❌ FirestoreReportsService.saveReport ERROR: $e');
      rethrow;
    }
  }
}
