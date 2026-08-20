import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/services/log_deduplication_service.dart';
import 'package:uuid/uuid.dart';

/// Service to manage daily logs with automatic deduplication
/// Keeps only highest risk entry per day
class DailyLogService {
  static final DailyLogService _instance = DailyLogService._internal();
  final List<DailyLog> _logs = [];

  factory DailyLogService() {
    return _instance;
  }

  DailyLogService._internal();

  /// Get today's log (highest risk for today)
  DailyLog? getTodayLog() {
    return getHighestRiskForDate(DateTime.now());
  }

  /// Create and add a new log
  void createAndAdd({
    required String condition,
    required int mood,
    required int itchIntensity,
    required int stressLevel,
    required String lesionSeverity,
    required List<String> affectedAreas,
    required int sleepQuality,
    required bool sleepDisruption,
    required String notes,
    DateTime? date,
    List<String>? triggers,
    List<String>? structuredTriggerIds,
    String? treatmentNoteAction,
    String? treatmentNoteText,
    // WEARABLE PREFILL AUDIT
    double? wearableRawSleepMinutes,
    int? wearableRawAwakenings,
    double? wearableRawDeviceStress,
    String? wearableProvider,
    DateTime? wearablePrefillSyncedAt,
    bool sleepQualityWasOverridden = false,
    bool sleepDisruptionWasOverridden = false,
    bool stressWasOverridden = false,
  }) {
    final newLog = DailyLog(
      id: const Uuid().v4(),
      condition: condition,
      mood: mood,
      itchIntensity: itchIntensity,
      stressLevel: stressLevel,
      lesionSeverity: lesionSeverity,
      affectedAreas: affectedAreas,
      sleepQuality: sleepQuality,
      sleepDisruption: sleepDisruption,
      notes: notes,
      date: date ?? DateTime.now(),
      triggers: triggers,
      structuredTriggerIds: structuredTriggerIds,
      treatmentNoteAction: treatmentNoteAction,
      treatmentNoteText: treatmentNoteText,
      wearableRawSleepMinutes: wearableRawSleepMinutes,
      wearableRawAwakenings: wearableRawAwakenings,
      wearableRawDeviceStress: wearableRawDeviceStress,
      wearableProvider: wearableProvider,
      wearablePrefillSyncedAt: wearablePrefillSyncedAt,
      sleepQualityWasOverridden: sleepQualityWasOverridden,
      sleepDisruptionWasOverridden: sleepDisruptionWasOverridden,
      stressWasOverridden: stressWasOverridden,
    );
    addLog(newLog);
  }

  /// Remove log by ID
  bool removeLogById(String logId) {
    return removeLog(logId);
  }

  /// Add a new log with automatic deduplication
  /// If a log already exists for today with lower risk, it gets replaced.
  /// Set [quiet] to true for bulk imports (e.g. Firestore sync) to avoid log spam.
  void addLog(DailyLog log, {bool quiet = false}) {
    final today = DateTime(log.date.year, log.date.month, log.date.day);

    // Find existing log for the same day
    final existingIndex = _logs.indexWhere((existingLog) {
      final existingDay = DateTime(
        existingLog.date.year,
        existingLog.date.month,
        existingLog.date.day,
      );
      return existingDay.isAtSameMomentAs(today);
    });

    if (existingIndex != -1) {
      // Log exists for this day
      final existingLog = _logs[existingIndex];
      final newRiskScore = log.calculateRiskScore();
      final existingRiskScore = existingLog.calculateRiskScore();

      if (newRiskScore > existingRiskScore) {
        // New log has higher risk - replace it
        _logs[existingIndex] = log;
        if (!quiet) {
          debugPrint(
            '✅ Replaced log for ${_formatDate(today)}: Risk $existingRiskScore → $newRiskScore',
          );
        }
      } else {
        // Existing log has higher or equal risk - keep existing
        if (!quiet) {
          debugPrint(
            '⏭️ Kept higher risk log for ${_formatDate(today)}: $existingRiskScore ≥ $newRiskScore',
          );
        }
      }
    } else {
      // No log for this day - add it
      _logs.add(log);
      if (!quiet) {
        debugPrint(
            '✅ Added new log for ${_formatDate(today)}: Risk ${log.calculateRiskScore()}');
      }
    }
  }

  /// Get all logs (deduplicated)
  List<DailyLog> getLogs() {
    return LogDeduplicationService.deduplicateByDay(_logs);
  }

  /// Get raw logs (including duplicates)
  List<DailyLog> getRawLogs() {
    return List.from(_logs);
  }

  /// Get logs from last N days
  List<DailyLog> getLogsFromLastDays(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final filtered = _logs.where((log) => log.date.isAfter(cutoffDate)).toList();
    return LogDeduplicationService.deduplicateByDay(filtered);
  }

  /// Get logs for a specific date
  List<DailyLog> getLogsForDate(DateTime date) {
    return LogDeduplicationService.getLogsForDate(_logs, date);
  }

  /// Get highest risk entry for a date
  DailyLog? getHighestRiskForDate(DateTime date) {
    return LogDeduplicationService.getHighestRiskForDate(_logs, date);
  }

  /// Get deduplication statistics
  Map<String, dynamic> getDeduplicationStats() {
    return LogDeduplicationService.getDeduplicationStats(_logs);
  }

  /// Get removal details for deduplication UI.
  /// Returns empty when no removals have been tracked (in-memory dedup does not track history).
  List<Map<String, dynamic>> getRemovalDetails() => [];

  /// Clear all logs
  void clearAllLogs() {
    _logs.clear();
    debugPrint('🗑️ All logs cleared');
  }

  /// Remove log by ID
  bool removeLog(String logId) {
    final initialLength = _logs.length;
    _logs.removeWhere((log) => log.id == logId);
    return _logs.length < initialLength;
  }

  /// Get log by ID
  DailyLog? getLogById(String logId) {
    try {
      return _logs.firstWhere((log) => log.id == logId);
    } catch (e) {
      return null;
    }
  }

  /// Export logs as JSON
  String exportLogsAsJson() {
    final deduplicatedLogs = getLogs();
    final jsonList = deduplicatedLogs.map((log) => log.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Get summary statistics
  Map<String, dynamic> getSummaryStats() {
    final deduplicatedLogs = getLogs();
    if (deduplicatedLogs.isEmpty) {
      return {
        'totalDays': 0,
        'avgRiskScore': 0,
        'maxRiskScore': 0,
      };
    }

    final riskScores = deduplicatedLogs.map((log) => log.calculateRiskScore()).toList();

    return {
      'totalDays': deduplicatedLogs.length,
      'avgRiskScore':
          (riskScores.reduce((a, b) => a + b) / riskScores.length).toStringAsFixed(1),
      'maxRiskScore': riskScores.reduce((a, b) => a > b ? a : b),
    };
  }

  /// Private helper to format date
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
