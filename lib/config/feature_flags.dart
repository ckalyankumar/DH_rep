/// Patient-facing clinical interpretation gates.
///
/// These flags hide UI only. InsightEngine, RiskScoreCalculator, and
/// RecommendationService keep running so doctor-portal and export data stay
/// intact. Remote values live at Firestore
/// `appConfig/clinicalInterpretationFlags`; missing or malformed fields fall
/// back to [FeatureFlags.defaults].
class FeatureFlags {
  static const firestoreCollection = 'appConfig';
  static const firestoreDocumentId = 'clinicalInterpretationFlags';

  static const showRiskScoreKey = 'showRiskScore';
  static const showRedFlagsKey = 'showRedFlags';
  static const showTriggerInsightsKey = 'showTriggerInsights';
  static const showRecommendationsKey = 'showRecommendations';

  /// Compile-time defaults used before the first snapshot and whenever the
  /// remote document is missing, unreadable, or a field is the wrong type.
  static const defaults = FeatureFlags(
    showRiskScore: true,
    showRedFlags: true,
    showTriggerInsights: true,
    showRecommendations: false,
  );

  final bool showRiskScore;
  final bool showRedFlags;
  final bool showTriggerInsights;
  final bool showRecommendations;

  const FeatureFlags({
    required this.showRiskScore,
    required this.showRedFlags,
    required this.showTriggerInsights,
    required this.showRecommendations,
  });

  /// Parse a Firestore document map. Unknown keys are ignored. A missing or
  /// non-bool field uses that flag's value from [defaults] — never the whole
  /// object — so one bad field cannot flip the others.
  factory FeatureFlags.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    return FeatureFlags(
      showRiskScore: _readBool(data[showRiskScoreKey], defaults.showRiskScore),
      showRedFlags: _readBool(data[showRedFlagsKey], defaults.showRedFlags),
      showTriggerInsights: _readBool(
        data[showTriggerInsightsKey],
        defaults.showTriggerInsights,
      ),
      showRecommendations: _readBool(
        data[showRecommendationsKey],
        defaults.showRecommendations,
      ),
    );
  }

  static bool _readBool(Object? value, bool fallback) {
    if (value is bool) return value;
    return fallback;
  }

  FeatureFlags copyWith({
    bool? showRiskScore,
    bool? showRedFlags,
    bool? showTriggerInsights,
    bool? showRecommendations,
  }) {
    return FeatureFlags(
      showRiskScore: showRiskScore ?? this.showRiskScore,
      showRedFlags: showRedFlags ?? this.showRedFlags,
      showTriggerInsights: showTriggerInsights ?? this.showTriggerInsights,
      showRecommendations: showRecommendations ?? this.showRecommendations,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FeatureFlags &&
            showRiskScore == other.showRiskScore &&
            showRedFlags == other.showRedFlags &&
            showTriggerInsights == other.showTriggerInsights &&
            showRecommendations == other.showRecommendations;
  }

  @override
  int get hashCode => Object.hash(
        showRiskScore,
        showRedFlags,
        showTriggerInsights,
        showRecommendations,
      );

  @override
  String toString() {
    return 'FeatureFlags('
        'showRiskScore: $showRiskScore, '
        'showRedFlags: $showRedFlags, '
        'showTriggerInsights: $showTriggerInsights, '
        'showRecommendations: $showRecommendations)';
  }
}
