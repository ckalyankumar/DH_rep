import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/models/daily_log.dart';

class FirestoreDailyLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  FirestoreDailyLogService({required this.userId});

  /// Use current authenticated user's ID for reads; fallback to userId when signed out
  String get _effectiveUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? userId;

  /// Get reference to user's daily logs collection
  CollectionReference<Map<String, dynamic>> get _logsCol =>
      _db.collection('users').doc(_effectiveUserId).collection('dailyLogs');

  /// Save a log to Firestore (create or update)
  Future<void> saveLog(DailyLog log) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint(
        '❌ FirestoreDailyLogService.saveLog ERROR: no authenticated user',
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('dailyLogs')
          .doc(log.id)
          .set(log.toJson(), SetOptions(merge: true));
      debugPrint('✅ Log saved to Firestore: ${log.id}');
    } catch (e) {
      debugPrint('❌ FirestoreDailyLogService.saveLog ERROR: $e');
      rethrow;
    }
  }

  /// Get a log for a specific date
  Future<DailyLog?> getLogForDate(DateTime date) async {
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final snap = await _logsCol
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThan: end.toIso8601String())
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return DailyLog.fromJson(snap.docs.first.data());
    } catch (e) {
      debugPrint('Error fetching log for date: $e');
      return null;
    }
  }

  /// Get logs from last N days, ordered by date (newest first)
  Future<List<DailyLog>> getLogsForLastDays(int days) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final snap = await _logsCol
          .where('date', isGreaterThanOrEqualTo: cutoff.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      return snap.docs
          .map((doc) => DailyLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching recent logs: $e');
      return [];
    }
  }

  /// Get ALL logs for a user
  Future<List<DailyLog>> getAllLogs() async {
    try {
      final snap = await _logsCol.orderBy('date', descending: true).get();
      return snap.docs
          .map((doc) => DailyLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all logs: $e');
      return [];
    }
  }

  /// Delete a log
  Future<void> deleteLog(String logId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint(
        '❌ FirestoreDailyLogService.deleteLog ERROR: no authenticated user',
      );
      return;
    }

    try {
      await _logsCol.doc(logId).delete();
      debugPrint('✅ Log deleted: $logId');
    } catch (e) {
      debugPrint('❌ FirestoreDailyLogService.deleteLog ERROR: $e');
      rethrow;
    }
  }

  /// Check if Firestore is accessible
  Future<bool> isConnected() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint(
        '❌ FirestoreDailyLogService.isConnected ERROR: no authenticated user',
      );
      // #region agent log
      try {
        File('debug-7bd69c.log').writeAsStringSync(
          '${jsonEncode({
                'sessionId': '7bd69c',
                'runId': 'pre-fix',
                'hypothesisId': 'H1',
                'location':
                    'lib/services/firestore_daily_log_service.dart:isConnected',
                'message': 'isConnected no authenticated user',
                'data': {},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              })}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
      return false;
    }

    try {
      await _db.collection('_health_check').doc('ping').set(
        {'timestamp': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      // #region agent log
      try {
        File('debug-7bd69c.log').writeAsStringSync(
          '${jsonEncode({
                'sessionId': '7bd69c',
                'runId': 'pre-fix',
                'hypothesisId': 'H1',
                'location':
                    'lib/services/firestore_daily_log_service.dart:isConnected',
                'message': 'isConnected success',
                'data': {'userId': _effectiveUserId},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              })}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
      return true;
    } catch (e) {
      debugPrint('Firestore not connected: $e');
      // #region agent log
      try {
        File('debug-7bd69c.log').writeAsStringSync(
          '${jsonEncode({
                'sessionId': '7bd69c',
                'runId': 'pre-fix',
                'hypothesisId': 'H1',
                'location':
                    'lib/services/firestore_daily_log_service.dart:isConnected',
                'message': 'isConnected error',
                'data': {'error': e.toString()},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              })}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
      return false;
    }
  }
}