import 'package:dhealth/models/daily_log.dart';

/// Collapses multiple same-day check-ins via [DailyLog.aggregateWithSameDay].
class LogDeduplicationService {
  /// One aggregated [DailyLog] per calendar day (per-field merge, not max-risk).
  static List<DailyLog> deduplicateByDay(List<DailyLog> logs) {
    if (logs.isEmpty) return [];

    final Map<String, List<DailyLog>> logsByDay = {};

    for (final log in logs) {
      final dayKey = _getDayKey(log.date);
      logsByDay.putIfAbsent(dayKey, () => []).add(log);
    }

    final List<DailyLog> deduplicatedLogs = [
      for (final dayLogs in logsByDay.values) DailyLog.aggregateAll(dayLogs),
    ];

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
          ? 'Aggregated multiple check-ins per day. Folded $logsRemoved extra entr${logsRemoved == 1 ? 'y' : 'ies'}'
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

  /// Aggregated log for a calendar date, or null if none.
  static DailyLog? getHighestRiskForDate(List<DailyLog> logs, DateTime date) {
    final logsForDay = getLogsForDate(logs, date);
    if (logsForDay.isEmpty) return null;
    return DailyLog.aggregateAll(logsForDay);
  }

  /// Private helper to get day key (YYYY-MM-DD)
  static String _getDayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
