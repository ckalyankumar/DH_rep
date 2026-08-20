/// Peer-reviewed clinical evidence citation with full metadata
/// Every rec requires PMID/DOI + GRADE for bulletproof clinical validation
class ClinicalEvidence {
  final String title;
  final String authors;
  final String year;
  final String journal;
  final String doi; // DOI number for linking
  final String? pmid; // PubMed ID (e.g. "28195077")
  final String url; // Link to PubMed or journal
  final String keyFinding; // 1-2 sentence key insight
  final int citationCount; // H-index relevance indicator
  final String evidenceType; // 'randomized_trial', 'meta_analysis', 'observational', 'guideline', 'review'
  final String? gradeLevel; // GRADE: 1A, 1B, 2A, 2B, 3, 4

  ClinicalEvidence({
    required this.title,
    required this.authors,
    required this.year,
    required this.journal,
    required this.doi,
    this.pmid,
    required this.url,
    required this.keyFinding,
    required this.citationCount,
    required this.evidenceType,
    this.gradeLevel,
  });

  /// PubMed URL when pmid is available
  String? get pubmedLink =>
      pmid != null && pmid!.isNotEmpty ? 'https://pubmed.ncbi.nlm.nih.gov/$pmid/' : null;

  /// Evidence strength rating: 1A (highest) to 5 (lowest) based on GRADE methodology
  String getEvidenceStrength() {
    if (gradeLevel != null && gradeLevel!.isNotEmpty) return gradeLevel!;
    if (evidenceType == 'randomized_trial' && citationCount > 50) {
      return '1A: High Quality RCT';
    }
    if (evidenceType == 'meta_analysis' && citationCount > 30) {
      return '1A: Systematic Review/Meta-Analysis';
    }
    if (evidenceType == 'randomized_trial') {
      return '1B: Randomized Controlled Trial';
    }
    if (evidenceType == 'meta_analysis') {
      return '1B: Meta-Analysis';
    }
    if (evidenceType == 'observational' && citationCount > 20) {
      return '2B: Large Observational Study';
    }
    if (evidenceType == 'guideline') {
      return '2A: Professional Guideline';
    }
    if (evidenceType == 'review') {
      return '3: Narrative Review';
    }
    return '4: Expert Opinion';
  }

  /// Citation format: Author (Year) Title. Journal. DOI
  String getCitation() {
    return '$authors ($year). "$title." $journal. https://doi.org/$doi';
  }

  /// Get a brief DOI link
  String getDOILink() {
    return 'https://doi.org/$doi';
  }

  /// Check if this is high-quality evidence
  bool get isHighQuality => citationCount > 50 && 
      (evidenceType == 'randomized_trial' || evidenceType == 'meta_analysis');

  @override
  String toString() {
    return '${getCitation()}\nKey Finding: $keyFinding\nCitations: $citationCount';
  }
}

/// Evidence-backed trigger with full mechanism explanation
class EvidencedTrigger {
  final String name;
  final String mechanism; // Detailed biological mechanism
  final double baselineIncidence; // % of condition sufferers affected by this trigger
  final List<String> symptoms; // Symptom codes affected
  final String preventionStrategy; // What to do
  final double expectedImprovement; // % PASI/SCORAD improvement expected
  final List<ClinicalEvidence> evidence; // Supporting papers
  final List<String>? applicableRegions; // e.g. ['IN'] for India-specific, null = global

  // Optional fields for personalization
  final int lagDays;
  final double correlation;
  final double confidence;

  EvidencedTrigger({
    required this.name,
    required this.mechanism,
    required this.baselineIncidence,
    required this.symptoms,
    required this.preventionStrategy,
    required this.expectedImprovement,
    required this.evidence,
    this.applicableRegions,
    this.lagDays = 0,
    this.correlation = 0.0,
    this.confidence = 0.0,
  });

  /// Get confidence level as text
  String getConfidenceLevel() {
    if (confidence >= 75) return 'Very High';
    if (confidence >= 50) return 'High';
    if (confidence >= 30) return 'Moderate';
    if (confidence >= 10) return 'Low';
    return 'Very Low';
  }

  /// Get evidence quality summary
  String getEvidenceQuality() {
    if (evidence.isEmpty) return 'Expert consensus';
    final strengths = evidence.map((e) => e.getEvidenceStrength()).toList();
    if (strengths.any((s) => s.startsWith('1A'))) {
      return 'High quality evidence (RCT/Meta-analysis)';
    }
    if (strengths.any((s) => s.startsWith('1B'))) {
      return 'Moderate evidence (RCT/Meta-analysis)';
    }
    return 'Supporting evidence available';
  }

  @override
  String toString() => '$name ($confidence% confidence, $expectedImprovement% expected improvement)';
}

/// Base interface for all clinical disorders (extensible for future conditions)
abstract class ClinicalDisorder {
  // Basic disorder information
  String get disorderName;
  String get icdCode; // WHO ICD-10 code (e.g., 'L40' for psoriasis)
  String get pathophysiology; // Detailed mechanism of disease
  List<String> get synonyms; // Alternative names

  // Clinical content
  List<EvidencedTrigger> get triggers; // Evidence-backed triggers
  List<TreatmentOption> get treatments; // Treatment options
  List<RedFlag> get redFlags; // Emergency warning signs

  // Risk factor categories
  List<String> get geneticRiskFactors;
  List<String> get environmentalRiskFactors;
  List<String> get lifestyleRiskFactors;

  // Research & evidence
  List<ClinicalEvidence> get keyResearchPapers;

  // Personalization threshold
  double get triggerCorrelationThreshold; // When to count as "their" trigger (0-1 scale)
}

/// Treatment option with evidence and monitoring
class TreatmentOption {
  final String name;
  final String category; // 'topical', 'systemic', 'biologic', 'behavioral', 'environmental'
  final String mechanism; // How it works
  final double efficacy; // % efficacy from trials (PASI-50, PASI-75, SCORAD improvement)
  final List<String> sideEffects;
  final List<ClinicalEvidence> evidence; // Supporting RCTs
  final int monitoringIntervalDays; // How often to assess (7, 14, 28)
  final List<String> contraindicationFlags; // When to avoid

  TreatmentOption({
    required this.name,
    required this.category,
    required this.mechanism,
    required this.efficacy,
    required this.sideEffects,
    required this.evidence,
    required this.monitoringIntervalDays,
    required this.contraindicationFlags,
  });

  /// Get efficacy as readable text
  String getEfficacyLabel() {
    if (efficacy >= 80) return 'Excellent (${efficacy.toStringAsFixed(0)}%)';
    if (efficacy >= 60) return 'Good (${efficacy.toStringAsFixed(0)}%)';
    if (efficacy >= 40) return 'Moderate (${efficacy.toStringAsFixed(0)}%)';
    return 'Fair (${efficacy.toStringAsFixed(0)}%)';
  }

  @override
  String toString() => '$name - $category (${efficacy.toStringAsFixed(0)}% efficacy)';
}

/// Personalized clinical insight with evidence
class ClinicalInsight {
  final String title;
  final String description;
  final String mechanism; // Why this matters
  final double confidence; // 0-100% based on data quality
  final String riskCategory; // 'critical', 'high', 'moderate', 'low'
  final List<ClinicalEvidence> supportingEvidence;
  final List<String> actionableSteps; // What to do
  final String expectedOutcome; // What improvement to expect + timeframe
  final DateTime discoveredAt;

  ClinicalInsight({
    required this.title,
    required this.description,
    required this.mechanism,
    required this.confidence,
    required this.riskCategory,
    required this.supportingEvidence,
    required this.actionableSteps,
    required this.expectedOutcome,
    required this.discoveredAt,
  });

  /// Get evidence quality summary
  String getEvidenceQuality() {
    if (supportingEvidence.isEmpty) return 'Expert consensus';
    final strengths = supportingEvidence.map((e) => e.getEvidenceStrength()).toList();
    if (strengths.any((s) => s.startsWith('1A'))) {
      return 'High quality evidence (RCT/Meta-analysis)';
    }
    if (strengths.any((s) => s.startsWith('1B'))) {
      return 'Moderate evidence';
    }
    return 'Supporting evidence available';
  }

  /// Get risk category emoji
  String getRiskEmoji() {
    switch (riskCategory) {
      case 'critical':
        return '🚨';
      case 'high':
        return '⛔';
      case 'moderate':
        return '⚠️';
      default:
        return '✅';
    }
  }

  @override
  String toString() =>
      '$title ($riskCategory, ${confidence.toStringAsFixed(0)}% confidence)';
}

/// Red flag symptoms requiring immediate medical attention
class RedFlag {
  final String symptom;
  final String urgency; // 'emergency', 'urgent', 'soon'
  final String whyImportant; // Clinical explanation
  final String actionToTake; // What patient should do
  /// Guideline source citation (e.g. "NPF/AAD", "AAD 2023", "EADV S3").
  final String? guidelineSource;

  RedFlag({
    required this.symptom,
    required this.urgency,
    required this.whyImportant,
    required this.actionToTake,
    this.guidelineSource,
  });

  /// Get urgency emoji
  String getUrgencyEmoji() {
    switch (urgency) {
      case 'emergency':
        return '🚨';
      case 'urgent':
        return '⛔';
      case 'soon':
        return '⚠️';
      default:
        return 'ℹ️';
    }
  }

  /// Get urgency color (for UI)
  String getUrgencyColor() {
    switch (urgency) {
      case 'emergency':
        return '#FF0000'; // Red
      case 'urgent':
        return '#FF8C00'; // Orange
      case 'soon':
        return '#FFD700'; // Gold
      default:
        return '#4CAF50'; // Green
    }
  }

  @override
  String toString() => '$getUrgencyEmoji $symptom - $actionToTake'
      '${guidelineSource != null ? ' ($guidelineSource)' : ''}';
}
