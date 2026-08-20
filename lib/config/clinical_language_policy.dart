/// DHealth Clinical Language Policy v1.0
///
/// All patient-facing and clinician-facing strings must use
/// associative language only.
///
/// Prohibited: "causes", "triggers" (as verb), "leads to",
///             "triggered by", "caused by", "worsened by"
///
/// Required: "is associated with", "correlates with",
///           "has been observed alongside", "may be associated with"
///
/// Regulatory basis: FDA General Wellness Policy 2016,
///                   CDSCO wellness classification,
///                   DHealth Clinical Governance Log v1.0
library;

class ClinicalLanguagePolicy {
  static const String associatedWith = 'is associated with';
  static const String observedAlongside = 'has been observed alongside';
  static const String correlatesWith = 'correlates with';
  static const String mayBeAssociatedWith = 'may be associated with';

  static String triggerInsight(String trigger, String outcome) =>
      '$trigger $associatedWith changes in $outcome';

  static String patternInsight(String factor, String symptom) =>
      'When $factor is elevated, $symptom $observedAlongside';

  static String lagInsight(String factor, int lagDays, String symptom) =>
      '$factor $correlatesWith $symptom observed $lagDays '
      '${lagDays == 1 ? "day" : "days"} later';
}
