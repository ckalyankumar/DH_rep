import 'package:dhealth/config/risk_score_config.dart';

/// Patient-specific weight profile for stress, mood, sleep, and optional hrv.
///
/// Derived from 90-day correlation data between triggers and symptom outcomes.
/// Used to personalize risk score so stress-driven vs sleep-driven patients
/// get different weights. Deterministic, no ML.
class PersonalWeightProfile {
  final double stressWeight;
  final double moodWeight;
  final double sleepWeight;
  final double blendFactor;
  final int dataDaysUsed;
  final bool isFromCorrelation;
  /// Optional HRV weight from wearable correlation (0 if not used).
  final double hrvWeight;

  const PersonalWeightProfile({
    required this.stressWeight,
    required this.moodWeight,
    required this.sleepWeight,
    required this.blendFactor,
    required this.dataDaysUsed,
    required this.isFromCorrelation,
    this.hrvWeight = 0,
  });

  /// Merge this profile into disorder defaults. Returns full RiskScoreWeights
  /// with stress, mood, sleep (and optional hrv) replaced by personalized values.
  RiskScoreWeights mergeInto(RiskScoreWeights disorderDefaults) {
    return RiskScoreWeights(
      itchWeight: disorderDefaults.itchWeight,
      lesionWeight: disorderDefaults.lesionWeight,
      extentWeight: disorderDefaults.extentWeight,
      stressWeight: stressWeight,
      moodWeight: moodWeight,
      sleepWeight: sleepWeight,
      envWeight: disorderDefaults.envWeight,
      hrvWeight: hrvWeight,
    );
  }
}
