/// Weekly self-efficacy pulse: "How confident do you feel in managing your
/// skin condition this week?" (0–10).
///
/// Captures self-efficacy distinct from symptom severity. A declining trend
/// over 4–6 weeks is a clinically meaningful signal (adherence risk, demoralization).
/// Single-item measures have reasonable validity for tracking trends.
class WeeklySelfEfficacyPulse {
  final String id;
  final DateTime weekStartDate; // Sunday of the week
  final int score; // 0–10
  final String condition;
  final DateTime createdAt;

  const WeeklySelfEfficacyPulse({
    required this.id,
    required this.weekStartDate,
    required this.score,
    required this.condition,
    required this.createdAt,
  });

  /// Get Sunday 00:00 of the week containing [date]
  static DateTime getWeekStart(DateTime date) {
    final weekday = date.weekday; // 1=Mon, 7=Sun
    final daysFromSunday = weekday == 7 ? 0 : weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: daysFromSunday));
  }

  /// Doc ID for Firestore: e.g. "2025-02-23"
  static String weekIdFromDate(DateTime weekStart) {
    return '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'weekStartDate': weekStartDate.toIso8601String(),
      'score': score,
      'condition': condition,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static WeeklySelfEfficacyPulse fromJson(Map<String, dynamic> json, {required String id}) {
    return WeeklySelfEfficacyPulse(
      id: id,
      weekStartDate: DateTime.parse(json['weekStartDate'] as String),
      score: json['score'] as int? ?? 0,
      condition: json['condition'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
