import 'package:dhealth/models/daily_log.dart';

/// Service to deduplicate daily logs
/// Keeps only 1 entry per day (highest risk score)
class LogDeduplicationService {
  /// Deduplicate logs - keep highest risk entry per day
  static List<DailyLog> deduplicateByDay(List<DailyLog> logs) {
    if (logs.isEmpty) return [];

    // Group logs by day
    final Map<String, List<DailyLog>> logsByDay = {};

    for (final log in logs) {
      final dayKey = _getDayKey(log.date);
      if (!logsByDay.containsKey(dayKey)) {
        logsByDay[dayKey] = [];
      }
      logsByDay[dayKey]!.add(log);
    }

    // For each day, keep only the highest risk entry
    final List<DailyLog> deduplicatedLogs = [];

    logsByDay.forEach((day, dayLogs) {
      dayLogs.sort((a, b) => b.calculateRiskScore().compareTo(a.calculateRiskScore()));
      deduplicatedLogs.add(dayLogs.first);
    });

    // Sort by date (most recent first)
    deduplicatedLogs.sort((a, b) => b.date.compareTo(a.date));

    return deduplicatedLogs;
  }

  /// Get summary of duplicates removed
  static Map<String, dynamic> getDeduplicationStats(List<DailyLog> logs) {
    if (logs.isEmpty) {
      return {
        'totalLogs': 0,
        'uniqueDays': 0,
        'logsRemoved': 0,
        'reductionPercentage': 0.0,
      };
    }

    final deduplicatedLogs = deduplicateByDay(logs);
    final logsRemoved = logs.length - deduplicatedLogs.length;
    final reductionPercentage = logsRemoved > 0 ? (logsRemoved / logs.length * 100) : 0.0;

    return {
      'totalLogs': logs.length,
      'uniqueDays': deduplicatedLogs.length,
      'logsRemoved': logsRemoved,
      'reductionPercentage': reductionPercentage.toStringAsFixed(1),
      'message': logsRemoved > 0
          ? 'Kept highest risk entry for each day. Removed $logsRemoved duplicate(s)'
          : 'All logs are unique (1 per day)',
    };
  }

  /// Check for duplicates on a specific date
  static List<DailyLog> getLogsForDate(List<DailyLog> logs, DateTime date) {
    final dayKey = _getDayKey(date);
    final logsForDay = logs.where((log) => _getDayKey(log.date) == dayKey).toList();
    logsForDay.sort((a, b) => b.date.compareTo(a.date));
    return logsForDay;
  }

  /// Get highest risk entry for a date
  static DailyLog? getHighestRiskForDate(List<DailyLog> logs, DateTime date) {
    final logsForDay = getLogsForDate(logs, date);
    if (logsForDay.isEmpty) return null;
    logsForDay.sort((a, b) => b.calculateRiskScore().compareTo(a.calculateRiskScore()));
    return logsForDay.first;
  }

  /// Private helper to get day key (YYYY-MM-DD)
  static String _getDayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
