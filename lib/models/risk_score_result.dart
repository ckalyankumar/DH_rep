/// Result of the explainable risk score calculation.
///
/// Contains final score, band, component breakdown, and modifiers
/// for transparent display in UI.
class RiskScoreResult {
  final int finalScore;
  final String band; // 'low' | 'moderate' | 'high' | 'urgent'
  final Map<String, double> components;
  final double trendModifier;
  final double triggerModifier;
  final bool redFlagOverride;
  final List<String> explanation;
  /// True when patient-specific weights (from 90-day correlation) were used.
  final bool usedPersonalWeights;
  /// Wearable-derived modifier (0 when not used).
  final int wearableModifier;

  const RiskScoreResult({
    required this.finalScore,
    required this.band,
    required this.components,
    required this.trendModifier,
    required this.triggerModifier,
    required this.redFlagOverride,
    required this.explanation,
    this.usedPersonalWeights = false,
    this.wearableModifier = 0,
  });

  /// Band thresholds: 0–30 low, 31–50 moderate, 51–70 high, 71+ urgent
  static String scoreToBand(int score) {
    if (score >= 85) return 'urgent';
    if (score >= 70) return 'high';
    if (score >= 50) return 'moderate';
    return 'low';
  }
}
