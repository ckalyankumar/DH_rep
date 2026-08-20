import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/services/trigger_normalization_service.dart';

class WeeklyFocusSuggestion {
  final String text; // one-line actionable suggestion shown to patient
  final String rationale; // one-line explanation drawn from patient data
  final String triggerCategory; // 'stress' | 'sleep' | 'diet' | 'environment' | 'general'
  final String recommendationId; // links to existing recommendation content
  final int rank; // 1 = most relevant, 2 = second, 3 = third

  WeeklyFocusSuggestion({
    required this.text,
    required this.rationale,
    required this.triggerCategory,
    required this.recommendationId,
    required this.rank,
  });
}

class WeeklyFocusSuggestionEngine {
  /// Generate 2-3 ranked suggestions for the current week.
  /// Returns between 1 and 3 suggestions; never returns an empty list.
  List<WeeklyFocusSuggestion> generateSuggestions({
    required List<DailyLog> recentLogs, // last 30 days
    required String condition,
    required List<ProAssessment> proAssessments,
  }) {
    final suggestions = <WeeklyFocusSuggestion>[];

    // 1. PRIMARY — Trigger correlation signal (last 14 days)
    _addPrimaryTriggerSuggestion(
      suggestions: suggestions,
      recentLogs: recentLogs,
      condition: condition,
    );

    // 2. SECONDARY — PRO trajectory signal
    _addProTrajectorySuggestion(
      suggestions: suggestions,
      proAssessments: proAssessments,
    );

    // 3. TERTIARY — Fallback to ensure at least one suggestion and
    // typically at least two suggestions when possible.
    if (suggestions.length < 2) {
      _addFallbackSuggestion(
        suggestions: suggestions,
        condition: condition,
      );
    }

    // Absolute guarantee: never return an empty list.
    if (suggestions.isEmpty) {
      _addFallbackSuggestion(
        suggestions: suggestions,
        condition: condition,
      );
    }

    return suggestions;
  }

  void _addPrimaryTriggerSuggestion({
    required List<WeeklyFocusSuggestion> suggestions,
    required List<DailyLog> recentLogs,
    required String condition,
  }) {
    if (recentLogs.isEmpty) return;

    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 14));

    // Filter logs to last 14 days.
    final last14DayLogs = recentLogs
        .where((log) => log.date.isAfter(cutoff) || _isSameDay(log.date, cutoff))
        .toList();

    if (last14DayLogs.isEmpty) return;

    final categoryCounts = <String, int>{};

    for (final log in last14DayLogs) {
      final topLevels = topLevelTriggersForLog(log);
      if (topLevels.isEmpty) continue;

      // Count per-log presence of each category.
      for (final cat in topLevels) {
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
    }

    if (categoryCounts.isEmpty) return;

    // Determine most frequent category.
    String? bestCategory;
    int bestCount = 0;
    categoryCounts.forEach((cat, count) {
      if (count > bestCount) {
        bestCount = count;
        bestCategory = cat;
      }
    });

    if (bestCategory == null || bestCount < 3) return;

    // Only handle known top-level categories that we have templates for.
    if (!_isSupportedTriggerCategory(bestCategory!)) return;

    final text = _primaryTextFor(bestCategory!, condition);
    final rationale = _primaryRationaleFor(bestCategory!, condition, bestCount);
    if (text == null || rationale == null) return;

    suggestions.add(
      WeeklyFocusSuggestion(
        text: text,
        rationale: rationale,
        triggerCategory: bestCategory!,
        recommendationId: _recommendationIdForCategory(bestCategory!),
        rank: suggestions.length + 1,
      ),
    );
  }

  void _addProTrajectorySuggestion({
    required List<WeeklyFocusSuggestion> suggestions,
    required List<ProAssessment> proAssessments,
  }) {
    if (proAssessments.isEmpty) return;

    ProTrajectoryAlert? alert =
        ProTrajectoryAlert.detectTrajectory(proAssessments, type: ProAssessmentType.poem);

    alert ??= ProTrajectoryAlert.detectTrajectory(
      proAssessments,
      type: ProAssessmentType.dlqi,
    );

    if (alert == null) return;

    const text =
        'Focus on one small skin care step you can do consistently every day this week';
    const rationale =
        'Your skin impact score has increased recently — small consistent habits help';

    suggestions.add(
      WeeklyFocusSuggestion(
        text: text,
        rationale: rationale,
        triggerCategory: 'general',
        recommendationId: _recommendationIdForCategory('general'),
        rank: suggestions.length + 1,
      ),
    );
  }

  void _addFallbackSuggestion({
    required List<WeeklyFocusSuggestion> suggestions,
    required String condition,
  }) {
    final normalizedCondition = condition.toLowerCase();
    String text;
    String rationale;

    if (normalizedCondition == 'eczema') {
      text =
          'Log your sleep quality every day this week — sleep is a key eczema driver';
      rationale =
          'Sleep data helps us understand your eczema pattern';
    } else {
      // Default to psoriasis-style fallback (also used when condition is unknown).
      text =
          'Log your triggers for 7 days — your personal pattern will become clearer';
      rationale =
          'More data helps identify what\'s driving your psoriasis';
    }

    suggestions.add(
      WeeklyFocusSuggestion(
        text: text,
        rationale: rationale,
        triggerCategory: 'general',
        recommendationId: _recommendationIdForCategory('general'),
        rank: suggestions.length + 1,
      ),
    );
  }

  bool _isSupportedTriggerCategory(String category) {
    switch (category) {
      case 'stress':
      case 'sleep':
      case 'diet':
      case 'environment':
        return true;
      default:
        return false;
    }
  }

  String? _primaryTextFor(String category, String condition) {
    final normalizedCondition = condition.toLowerCase();

    switch (category) {
      case 'stress':
        return normalizedCondition == 'eczema'
            ? 'Try a short breathing exercise before bed on high-stress days'
            : 'Try one deliberate wind-down activity on your next stressful evening';
      case 'sleep':
        return normalizedCondition == 'eczema'
            ? 'Keep your bedroom cool and use light cotton bedding this week'
            : 'Aim to be in bed 30 minutes earlier than usual this week';
      case 'diet':
        return normalizedCondition == 'eczema'
            ? 'Try identifying one food item that preceded a flare this week'
            : 'Try one alcohol-free day this week and note how your skin feels';
      case 'environment':
        return normalizedCondition == 'eczema'
            ? 'Check labels on any new soaps, detergents, or fabrics you used this week'
            : 'Apply moisturiser immediately after exposure to cold or dry air this week';
      default:
        return null;
    }
  }

  String? _primaryRationaleFor(
    String category,
    String condition,
    int countInLast14Logs,
  ) {
    final normalizedCondition = condition.toLowerCase();

    switch (category) {
      case 'stress':
        return normalizedCondition == 'eczema'
            ? 'Stress appeared in $countInLast14Logs of your last 14 logs — your highest trigger this week'
            : 'Stress appeared in $countInLast14Logs of your last 14 logs — your highest trigger this week';
      case 'sleep':
        return normalizedCondition == 'eczema'
            ? 'Sleep disruption appeared in $countInLast14Logs of your last 14 logs'
            : 'Poor sleep appeared in $countInLast14Logs of your last 14 logs';
      case 'diet':
        return 'Diet-related triggers appeared in $countInLast14Logs of your last 14 logs';
      case 'environment':
        return 'Environmental triggers appeared in $countInLast14Logs of your last 14 logs';
      default:
        return null;
    }
  }

  static String _recommendationIdForCategory(String category) {
    switch (category) {
      case 'stress':
        return 'rec_stress_winddown';
      case 'sleep':
        return 'rec_sleep_hygiene';
      case 'diet':
        return 'rec_diet_trigger';
      case 'environment':
        return 'rec_environment_barrier';
      case 'general':
      default:
        return 'rec_general_logging';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

