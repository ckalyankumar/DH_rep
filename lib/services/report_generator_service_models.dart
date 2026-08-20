import 'package:intl/intl.dart';

/// Internal red flag event model used by the report generator.
class RedFlagEvent {
  final DateTime date;
  final int riskScore;
  final List<String> triggers;
  final int itch;
  final int mood;

  const RedFlagEvent({
    required this.date,
    required this.riskScore,
    required this.triggers,
    required this.itch,
    required this.mood,
  });
}

class RedFlagSummary {
  final List<RedFlagEvent> events;
  final int totalRedFlagDays;
  final DateTime? mostRecent;
  final double redFlagRate;

  const RedFlagSummary({
    required this.events,
    required this.totalRedFlagDays,
    required this.mostRecent,
    required this.redFlagRate,
  });

  bool get hasEvents => totalRedFlagDays > 0;
}

class DataGaps {
  final int significantGapCount;
  final int longestGapDays;
  final DateTime? longestGapStart;
  final DateTime? longestGapEnd;

  const DataGaps({
    required this.significantGapCount,
    required this.longestGapDays,
    required this.longestGapStart,
    required this.longestGapEnd,
  });

  bool get hasSignificantGaps => significantGapCount > 0;

  String formatLongestGapRange() {
    if (longestGapStart == null || longestGapEnd == null) return '';
    final fmt = DateFormat('dd MMM yyyy');
    return '${fmt.format(longestGapStart!)} – ${fmt.format(longestGapEnd!)}';
  }
}

