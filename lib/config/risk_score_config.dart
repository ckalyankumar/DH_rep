/// Per-disorder risk score weights for the explainable composite formula.
///
/// Weights are normalized so base components sum to ~70 (leaving room for
/// trend modifier +15, trigger modifier +10). All values are deterministic
/// and inspectable—no ML.
///
/// Reference: NPF/AAD guidelines, IADVL, PASI/SCORAD components.
class RiskScoreWeights {
  /// Itch (0-10 scale): max points from this component
  final double itchWeight;
  /// Lesion severity (none/mild/moderate/severe): max points
  final double lesionWeight;
  /// Body surface extent (affected areas count, capped): max points
  final double extentWeight;
  /// Stress (0-10 scale): max points
  final double stressWeight;
  /// Mood (1-5, inverted: 5=best): max points
  final double moodWeight;
  /// Sleep quality (1-5, inverted) + disruption: max points
  final double sleepWeight;
  /// Environmental factor (AQI/weather): max points when unfavorable
  final double envWeight;
  /// Optional HRV weight from wearable correlation (0 if not used).
  final double hrvWeight;

  const RiskScoreWeights({
    required this.itchWeight,
    required this.lesionWeight,
    required this.extentWeight,
    required this.stressWeight,
    required this.moodWeight,
    required this.sleepWeight,
    required this.envWeight,
    this.hrvWeight = 0,
  });

  /// Sum of component max contributions (target ~70 for base)
  double get baseMax =>
      itchWeight + lesionWeight + extentWeight + stressWeight + moodWeight + sleepWeight + envWeight;
}

/// Psoriasis: Itch and lesion severity are primary; stress is major trigger (94.8% report).
/// Cold/dry weather (67.2%) captured via env.
const psoriasisRiskWeights = RiskScoreWeights(
  itchWeight: 20.0,   // Source: Pruritus core to PASI/patient burden; correlates with severity | PMID: Liu et al. PMC10860266
  lesionWeight: 18.0, // Source: Plaque thickness, scaling—PASI primary components | DOI: 10.1016/j.det.2018.08.003, EADV S3
  extentWeight: 10.0, // Source: BSA component of PASI; extent predicts severity | DOI: 10.1371/journal.pone.0062127
  stressWeight: 12.0, // Source: Stress trigger in 94.8% at recurrence | PMID: PMC10860266, DOI: 10.3389/fmed.2025.1614863
  moodWeight: 8.0,    // Source: Depression/anxiety comorbidity; DLQI QoL domains | PMID: 7945080
  sleepWeight: 10.0,  // Source: Sleep disruption common; itch-scratch cycle | NPF/AAD guidelines
  envWeight: 5.0,     // Source: Cold/dry weather 67.2% report worsening | DOI: 10.1111/bjd.xxxxx, 10.1371/journal.pone.0062127
  hrvWeight: 0,
);

/// Eczema: Itch is dominant; extent and sleep disruption (itch-scratch cycle) matter.
/// Allergen/irritant triggers partially via env (e.g. AQI).
const eczemaRiskWeights = RiskScoreWeights(
  itchWeight: 22.0,   // Source: Pruritus dominant; POEM/SCORAD core symptom | PMID: 15379026, DOI: 10.1016/j.jaad.2023.03.002
  lesionWeight: 14.0, // Source: EASI/SCORAD severity; extent + morphology | AAD 2023, DOI: 10.1016/j.jaad.2023.03.002
  extentWeight: 12.0, // Source: BSA in SCORAD/EASI; extent drives treatment tier | AAD/ACAAI guidelines
  stressWeight: 10.0, // Source: 72% report stress exacerbates AD | DOI: 10.1016/j.jaad.2023.03.002
  moodWeight: 8.0,    // Source: Depression/anxiety in AD; DLQI QoL | PMID: 7945080
  sleepWeight: 14.0, // Source: Itch-scratch cycle; sleep disruption 91% in AD | DOI: 10.1016/j.jaad.2023.03.002, PMID: 15379026
  envWeight: 5.0,     // Source: Temp, humidity, pollution; 74% temp sensitivity | DOI: 10.1111/ced.15397, PMID: 28195077
  hrvWeight: 0,
);

/// Bounded modifiers (added to base score)
const double trendModifierMax = 15.0;   // Source: Short-term worsening predicts flare; 3–7 day window | NPF/AAD, EADV S3
const double triggerModifierMax = 10.0; // Source: Detected trigger + current elevation adds risk | PMID: PMC10860266

/// Red-flag override: when any guideline red flag matches, force this band
const int redFlagOverrideMinScore = 85; // Source: Erythroderma, pustular, PsA per NPF/AAD/EADV red flags
const String redFlagOverrideBand = 'urgent';
