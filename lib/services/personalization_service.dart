import 'package:dhealth/models/recommendation_model.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/data/disorder_registry.dart';

/// Formula-based personalization: reorders recommendations by relevance.
/// 100% rule-based, no AI generation. Uses InsightEngine for trigger/pattern detection.
class PersonalizationService {
  /// Get personalized recommendations: reordered by detected triggers, risk, and patterns.
  /// Falls back to default order when insufficient log data.
  static List<Recommendation> getPersonalizedRecommendations(
    String condition,
    List<Recommendation> baseRecs, {
    List<DailyLog>? logs,
    List<dynamic>? logsDynamic,
  }) {
    final resolvedLogs = logs ??
        (logsDynamic?.whereType<DailyLog>().toList() ?? <DailyLog>[]);
    if (resolvedLogs.isEmpty) return baseRecs;
    if (resolvedLogs.length < 7) return baseRecs;

    final disorder = DisorderRegistry.getDisorder(condition);
    final detectedTriggers =
        InsightEngine.identifyTriggers(resolvedLogs, condition, disorder);
    final riskScore = _computeRiskScore(resolvedLogs);
    final triggerNames = detectedTriggers
        .map((t) => t.name.toLowerCase())
        .toSet();

    // Priority 1: Recs matching detected triggers (by title/tags)
    final triggerMatched = <Recommendation>[];
    final rest = <Recommendation>[];

    for (final rec in baseRecs) {
      final titleLower = rec.title.toLowerCase();
      final tagsLower = rec.tags.map((t) => t.toLowerCase()).toSet();
      final matchesTrigger = triggerNames.any((t) =>
          titleLower.contains(t) ||
          tagsLower.any((tag) => tag.contains(t) || t.contains(tag)));
      if (matchesTrigger) {
        triggerMatched.add(rec);
      } else {
        rest.add(rec);
      }
    }

    // Priority 2: High-priority recs when risk > 70
    final highRisk = riskScore > 70;
    final highPriority = rest
        .where((r) => r.priority == RecommendationPriority.high)
        .toList();
    final other = rest.where((r) => r.priority != RecommendationPriority.high).toList();

    // Build order: trigger-matched first, then high-priority if high risk, then rest
    final ordered = <Recommendation>[...triggerMatched];
    if (highRisk) {
      for (final r in highPriority) {
        if (!ordered.contains(r)) ordered.add(r);
      }
    }
    for (final r in other) {
      if (!ordered.contains(r)) ordered.add(r);
    }

    return ordered;
  }

  static double _computeRiskScore(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    final recent = logs.take(14).toList();
    final avg =
        recent.map((l) => l.calculateRiskScore()).reduce((a, b) => a + b) /
            recent.length;
    return avg;
  }

  /// Personalization score 0-100 based on data quality and match strength
  static int getPersonalizationScore(
    List<DailyLog> logs,
    List<Recommendation> ordered,
    List<Recommendation> triggerMatched,
  ) {
    if (logs.length < 7) return 0;
    var score = 0;
    if (logs.length >= 14) {
      score += 30;
    } else if (logs.length >= 10) {
      score += 20;
    } else {
      score += 10;
    }
    if (triggerMatched.isNotEmpty) score += 40;
    if (ordered.length > 5) score += 20;
    return score.clamp(0, 100);
  }
}
