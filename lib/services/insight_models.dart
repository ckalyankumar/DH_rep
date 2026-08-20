/// Core data structures for insights
class Insight {
  final String id;
  final String title;
  final String description;
  final double confidence; // 0-100%
  final String category; // 'trigger', 'pattern', 'recommendation', 'prediction'
  final DateTime discoveredAt;
  final String actionable; // What user should do
  final Map<String, dynamic> metadata;

  Insight({
    required this.id,
    required this.title,
    required this.description,
    required this.confidence,
    required this.category,
    required this.discoveredAt,
    required this.actionable,
    this.metadata = const {},
  });

  @override
  String toString() => '$title ($confidence% confidence)';
}

class Trigger {
  final String name;
  final double correlation; // Pearson: -1 to 1
  final int occurrences; // How many times detected
  final List<String> affectedMetrics; // What gets affected
  final String recommendation;
  final DateTime firstDetected;

  Trigger({
    required this.name,
    required this.correlation,
    required this.occurrences,
    required this.affectedMetrics,
    required this.recommendation,
    required this.firstDetected,
  });

  /// Correlation strength: 0-0.3 weak, 0.3-0.7 moderate, 0.7+ strong
  String getStrength() {
    final abs = correlation.abs();
    if (abs < 0.3) return 'Weak';
    if (abs < 0.7) return 'Moderate';
    return 'Strong';
  }

  @override
  String toString() => '$name (${getStrength()} correlation: ${correlation.toStringAsFixed(2)})';
}

class PatternInsight {
  final String pattern; // e.g., "Weekly Cycle", "Sleep Dependent"
  final String description;
  final double accuracy; // How accurate is this pattern
  final List<DateTime> occurrences;
  final String predictability; // 'high', 'medium', 'low'

  PatternInsight({
    required this.pattern,
    required this.description,
    required this.accuracy,
    required this.occurrences,
    required this.predictability,
  });
}

class Recommendation {
  final String title;
  final String description;
  final String type; // 'lifestyle', 'medication', 'prevention', 'urgent'
  final int priority; // 1-10 (10 = most urgent)
  final List<String> steps;
  final String expectedBenefit; // e.g., "25% improvement in itch control"
  final DateTime validUntil;

  Recommendation({
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.steps,
    required this.expectedBenefit,
    required this.validUntil,
  });

  String get icon {
    switch (type) {
      case 'lifestyle':
        return '🏃';
      case 'medication':
        return '💊';
      case 'prevention':
        return '🛡️';
      case 'urgent':
        return '🚨';
      default:
        return '💡';
    }
  }
}

class FlareRiskPrediction {
  final double riskPercentage; // 0-100%
  final int daysAhead; // Prediction window
  final List<String> topTriggers; // What causes it
  final List<Recommendation> preventiveActions;
  final DateTime calculatedAt;

  FlareRiskPrediction({
    required this.riskPercentage,
    required this.daysAhead,
    required this.topTriggers,
    required this.preventiveActions,
    required this.calculatedAt,
  });

  String get riskLevel {
    if (riskPercentage < 30) return 'Low';
    if (riskPercentage < 60) return 'Moderate';
    if (riskPercentage < 80) return 'High';
    return 'Very High';
  }

  String get riskEmoji {
    if (riskPercentage < 30) return '✅';
    if (riskPercentage < 60) return '⚠️';
    if (riskPercentage < 80) return '⛔';
    return '🚨';
  }
}

class StreakInfo {
  final int currentStreak; // Current consecutive good days
  final int bestStreak; // Best ever
  final double motivationScore; // 0-100%
  final List<DateTime> goodDays;
  final DateTime streakStartDate;

  StreakInfo({
    required this.currentStreak,
    required this.bestStreak,
    required this.motivationScore,
    required this.goodDays,
    required this.streakStartDate,
  });

  String get streakEmoji {
    if (currentStreak < 3) return '🔥';
    if (currentStreak < 7) return '🔥🔥';
    if (currentStreak < 14) return '🔥🔥🔥';
    return '🏆';
  }
}

class WearableMetric {
  final String type; // 'heart_rate', 'hrv', 'sleep', 'steps', 'calories'
  final double value;
  final DateTime recordedAt;
  final Map<String, dynamic> rawData;

  WearableMetric({
    required this.type,
    required this.value,
    required this.recordedAt,
    this.rawData = const {},
  });
}

class WearableInsight {
  final String metric; // e.g., 'HRV', 'Sleep Quality'
  final double value;
  final String interpretation;
  final bool actionable;
  final String recommendation;
  final double correlationWithSymptoms;

  WearableInsight({
    required this.metric,
    required this.value,
    required this.interpretation,
    required this.actionable,
    required this.recommendation,
    required this.correlationWithSymptoms,
  });

  @override
  String toString() => '$metric: $value - $interpretation';
}

/// Correlation between a trigger category and validated PRO scores (POEM / DLQI).
class TriggerProCorrelation {
  /// Top-level trigger category: 'stress', 'sleep', 'diet', 'environment', etc.
  final String category;

  /// Spearman rank correlation coefficient between weekly trigger frequency and PRO score.
  /// Positive values mean "more of this trigger ↔ worse scores".
  final double r;

  /// Number of weeks included in the analysis.
  final int weeks;

  /// Average PRO score in weeks with higher trigger exposure.
  final double avgProHigh;

  /// Average PRO score in weeks with lower trigger exposure.
  final double avgProLow;

  TriggerProCorrelation({
    required this.category,
    required this.r,
    required this.weeks,
    required this.avgProHigh,
    required this.avgProLow,
  });

  String get strength {
    final abs = r.abs();
    if (abs < 0.3) return 'weak';
    if (abs < 0.6) return 'moderate';
    return 'strong';
  }
}

class DailyInsightSummary {
  final DateTime date;
  final List<Insight> insights;
  final List<Recommendation> recommendations;
  final FlareRiskPrediction? flareRisk;
  final StreakInfo? streak;
  final List<WearableInsight> wearableInsights;

  DailyInsightSummary({
    required this.date,
    required this.insights,
    required this.recommendations,
    required this.flareRisk,
    required this.streak,
    required this.wearableInsights,
  });

  /// Overall health score for the day (0-100)
  double getHealthScore() {
    if (insights.isEmpty) return 50;
    final avgConfidence = insights.map((i) => i.confidence).reduce((a, b) => a + b) / insights.length;
    return avgConfidence;
  }
}
