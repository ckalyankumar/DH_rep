import 'package:dhealth/models/daily_log.dart';

/// Logging-density based confidence signal for insights and risk scores.
///
/// For now this is a simple 7-day window metric:
/// - High:   >= 5 distinct log days in the last 7 days
/// - Medium: 3–4 distinct log days
/// - Low:    < 3 distinct log days
class LogDensityConfidence {
  final String level; // 'high' | 'medium' | 'low'
  final int loggedDays;
  final int windowDays;

  const LogDensityConfidence({
    required this.level,
    required this.loggedDays,
    required this.windowDays,
  });

  /// Human-friendly label for UI display.
  String get label {
    switch (level) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  bool get isLow => level == 'low';

  /// Compute logging-density confidence over the last 7 calendar days.
  ///
  /// Uses distinct local dates with >= 1 log as the density measure.
  static LogDensityConfidence forLast7Days(
    List<DailyLog> logs, {
    DateTime? now,
  }) {
    if (logs.isEmpty) {
      return const LogDensityConfidence(
        level: 'low',
        loggedDays: 0,
        windowDays: 7,
      );
    }

    final today = now ?? DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final windowStart =
        todayDateOnly.subtract(const Duration(days: 6)); // inclusive

    final distinctDays = <DateTime>{};

    for (final log in logs) {
      final d = DateTime(log.date.year, log.date.month, log.date.day);
      if (!d.isBefore(windowStart) && !d.isAfter(todayDateOnly)) {
        distinctDays.add(d);
      }
    }

    final count = distinctDays.length;
    String level;
    if (count >= 5) {
      level = 'high';
    } else if (count >= 3) {
      level = 'medium';
    } else {
      level = 'low';
    }

    return LogDensityConfidence(
      level: level,
      loggedDays: count,
      windowDays: 7,
    );
  }
}

