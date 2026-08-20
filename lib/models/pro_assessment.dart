/// Types of patient-reported outcome (PRO) questionnaires.
///
/// - POEM: Patient-Oriented Eczema Measure (eczema-specific)
/// - DLQI: Dermatology Life Quality Index (commonly used for psoriasis)
library;

// ---------------------------------------------------------------------------
// POEM validation constants and citations
// ---------------------------------------------------------------------------
//
// POEM severity bands source:
//   Charman CR, Venn AJ, Williams HC. "The Patient-Oriented Eczema Measure"
//   Br J Dermatol. 2004;150(3):539-544. PMID 15379026
//
// POEM MCID (3.4 points) and responder threshold (5-point improvement):
//   Schram ME et al. "Establishing the minimal clinically important
//   difference of the patient-oriented eczema measure in atopic dermatitis."
//   Br J Dermatol. 2012;167(2):449-454. PMID 25529619
//
class PoemValidation {
  /// Minimal clinically important difference for POEM score change.
  /// Change must be >= this to label as "improving" or "worsening".
  static const double poemMcid = 3.4;

  /// Threshold for "responder" (clinically meaningful improvement).
  static const double poemResponderThreshold = 5.0;

  /// PMID for POEM development and validation (Charman et al.).
  static const String poemValidationPmid = '15379026';

  /// PMID for POEM MCID (Schram et al.).
  static const String poemMcidPmid = '25529619';

  /// Returns "improving", "worsening", or "stable" for POEM score change.
  /// Labels fire only when |change| >= 3.4 (MCID). Use < not <= so that:
  /// - change of 3 points → stable (3 < 3.4)
  /// - change of 4 points → meaningful (4 >= 3.4)
  static String poemTrendLabel(int previousScore, int currentScore) {
    final change = currentScore - previousScore;
    final absChange = change.abs();
    if (absChange < poemMcid) return 'stable'; // 3 points: stable; 4 points: meaningful
    return change < 0 ? 'improving' : 'worsening';
  }
}

// ---------------------------------------------------------------------------
// DLQI validation constants and citations
// ---------------------------------------------------------------------------
//
// DLQI development source:
//   Finlay AY, Khan GK. "Dermatology Life Quality Index (DLQI) - a simple
//   practical measure for routine clinical use." Clin Exp Dermatol. 1994.
//   PMID 7945080
//
// DLQI MCID (4 points): Shikiar R et al. / EADV consensus
//
// DLQI biologic threshold: DLQI >= 10 required for biologic eligibility
// per NICE TA and EADV S3 psoriasis guidelines
//
class DlqiValidation {
  /// Minimal clinically important difference for DLQI score change.
  /// Change must be >= this to label as "improving" or "worsening".
  static const double dlqiMcid = 4.0;

  /// DLQI >= 10 meets biologic eligibility threshold per NICE TA and EADV S3.
  static const double dlqiBiologicThreshold = 10.0;

  /// PMID for DLQI development (Finlay, Khan).
  static const String dlqiDevelopmentPmid = '7945080';

  /// Returns "improving", "worsening", or "stable" for DLQI score change.
  /// Labels fire only when |current - previous| >= dlqiMcid (4.0).
  static String dlqiTrendLabel(int previousScore, int currentScore) {
    final change = currentScore - previousScore;
    final absChange = change.abs();
    if (absChange < dlqiMcid) return 'stable';
    return change < 0 ? 'improving' : 'worsening';
  }

  /// True if DLQI score meets biologic eligibility (>= 10) per NICE TA and EADV S3.
  static bool isDlqiBiologicEligible(double score) => score >= dlqiBiologicThreshold;
}

class ProAssessmentType {
  static const String poem = 'POEM';
  static const String dlqi = 'DLQI';
}

/// Trajectory alert for a PRO instrument (POEM / DLQI).
///
/// Encodes the last clinically meaningful change crossing a band boundary.
class ProTrajectoryAlert {
  final String type; // ProAssessmentType.poem / ProAssessmentType.dlqi
  final int fromScore;
  final int toScore;
  final String fromBand;
  final String toBand;
  /// 'improving', 'worsening', or 'stable' (from validation helpers).
  final String label;
  final DateTime fromDate;
  final DateTime toDate;
  /// True when this represents a worsening trajectory that crossed a band boundary.
  final bool triggered;

  const ProTrajectoryAlert({
    required this.type,
    required this.fromScore,
    required this.toScore,
    required this.fromBand,
    required this.toBand,
    required this.label,
    required this.fromDate,
    required this.toDate,
    required this.triggered,
  });

  /// Detect a clinically-meaningful trajectory for the given PRO [type].
  ///
  /// Uses MCID-enforced trend labels from DlqiValidation / PoemValidation and
  /// requires a worsening change that crosses at least one severity band.
  static ProTrajectoryAlert? detectTrajectory(
    List<ProAssessment> assessments, {
    required String type,
  }) {
    final filtered = assessments
        .where((a) => a.type == type)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (filtered.length < 2) return null;

    final prev = filtered[filtered.length - 2];
    final curr = filtered[filtered.length - 1];

    // Require a minimum temporal gap (e.g. 14 days) to avoid firing on
    // tightly clustered repeat questionnaires before a stable pattern exists.
    final gapDays = curr.date.difference(prev.date).inDays.abs();
    if (gapDays < 14) return null;

    String label;
    if (type == ProAssessmentType.dlqi) {
      label = DlqiValidation.dlqiTrendLabel(prev.totalScore, curr.totalScore);
    } else {
      label = PoemValidation.poemTrendLabel(prev.totalScore, curr.totalScore);
    }

    if (label != 'worsening') {
      // Either improving or stable; no alert.
      return null;
    }

    final prevBandIndex = type == ProAssessmentType.dlqi
        ? _dlqiBandIndex(prev.severityBand)
        : _poemBandIndex(prev.severityBand);
    final currBandIndex = type == ProAssessmentType.dlqi
        ? _dlqiBandIndex(curr.severityBand)
        : _poemBandIndex(curr.severityBand);

    // Only alert when moving to a worse band.
    final crossedBoundary = currBandIndex > prevBandIndex;
    if (!crossedBoundary) return null;

    return ProTrajectoryAlert(
      type: type,
      fromScore: prev.totalScore,
      toScore: curr.totalScore,
      fromBand: prev.severityBand,
      toBand: curr.severityBand,
      label: label,
      fromDate: prev.date,
      toDate: curr.date,
      triggered: true,
    );
  }

  // Band ordering helpers – purely ordinal, reuse existing band strings.
  static int _dlqiBandIndex(String band) {
    final normalized = band.toLowerCase().trim();
    if (normalized.startsWith('no effect')) return 0;
    if (normalized.startsWith('small effect')) return 1;
    if (normalized.startsWith('moderate')) return 2;
    if (normalized.startsWith('very large')) return 3;
    if (normalized.startsWith('extremely')) return 4;
    return 0;
  }

  static int _poemBandIndex(String band) {
    final normalized = band.toLowerCase().trim();
    if (normalized.startsWith('clear')) return 0;
    if (normalized.startsWith('mild')) return 1;
    if (normalized.startsWith('moderate')) return 2;
    if (normalized.startsWith('severe')) return 3;
    if (normalized.startsWith('very severe')) return 4;
    return 0;
  }
}

/// A completed PRO assessment instance stored per user.
///
/// Firestore path: users/{userId}/proAssessments/{id}
class ProAssessment {
  final String id;
  final String type; // ProAssessmentType.*
  final String condition; // 'psoriasis', 'eczema', etc.
  final DateTime date; // completion date
  final int totalScore;
  final String severityBand; // e.g. 'clear/almost clear', 'moderate', etc.
  final List<ProItemResponse> responses;

  ProAssessment({
    required this.id,
    required this.type,
    required this.condition,
    required this.date,
    required this.totalScore,
    required this.severityBand,
    required this.responses,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'condition': condition,
      'date': date.toIso8601String(),
      'totalScore': totalScore,
      'severityBand': severityBand,
      'responses': responses.map((r) => r.toJson()).toList(),
    };
  }

  static ProAssessment fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) {
    return ProAssessment(
      id: id,
      type: json['type'] as String? ?? ProAssessmentType.poem,
      condition: json['condition'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      totalScore: json['totalScore'] as int? ?? 0,
      severityBand: json['severityBand'] as String? ?? '',
      responses: (json['responses'] as List<dynamic>? ?? [])
          .map((e) => ProItemResponse.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}

/// Response to a single questionnaire item.
class ProItemResponse {
  final String itemId; // stable key, e.g. 'poem_1'
  final String questionText;
  final int score; // numeric score for this item

  ProItemResponse({
    required this.itemId,
    required this.questionText,
    required this.score,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'questionText': questionText,
      'score': score,
    };
  }

  static ProItemResponse fromJson(Map<String, dynamic> json) {
    return ProItemResponse(
      itemId: json['itemId'] as String? ?? '',
      questionText: json['questionText'] as String? ?? '',
      score: json['score'] as int? ?? 0,
    );
  }
}

/// Configuration and scoring helpers for supported PRO instruments.
class ProQuestionnaireConfig {
  /// Metadata for one question.
  final String id;
  final String text;
  final List<String> options; // ordered labels; index is the score.

  const ProQuestionnaireConfig({
    required this.id,
    required this.text,
    required this.options,
  });

  // ---------------------------------------------------------------------------
  // POEM (Patient-Oriented Eczema Measure)
  // POEM severity bands source: Charman CR, Venn AJ, Williams HC.
  // "The Patient-Oriented Eczema Measure" PMID 15379026
  // POEM MCID (3.4 points): Schram ME et al. PMID 25529619
  // POEM responder threshold (5-point improvement): same source (Schram et al.)
  // ---------------------------------------------------------------------------

  static List<ProQuestionnaireConfig> poemQuestions() {
    const freqOptions = [
      'No days',
      '1–2 days',
      '3–4 days',
      '5–6 days',
      'Every day',
    ];

    return const [
      ProQuestionnaireConfig(
        id: 'poem_1',
        text: 'Over the last week, on how many days has your skin been itchy?',
        options: freqOptions,
      ),
      ProQuestionnaireConfig(
        id: 'poem_2',
        text:
            'Over the last week, on how many nights has your sleep been disturbed alongside your skin?', // Language policy: associative only — no causal claims
        options: freqOptions,
      ),
      ProQuestionnaireConfig(
        id: 'poem_3',
        text:
            'Over the last week, on how many days has your skin been bleeding?',
        options: freqOptions,
      ),
      ProQuestionnaireConfig(
        id: 'poem_4',
        text:
            'Over the last week, on how many days has your skin been weeping or oozing clear fluid?',
        options: freqOptions,
      ),
      ProQuestionnaireConfig(
        id: 'poem_5',
        text:
            'Over the last week, on how many days has your skin been cracked?',
        options: freqOptions,
      ),
      ProQuestionnaireConfig(
        id: 'poem_6',
        text:
            'Over the last week, on how many days has your skin been flaking off?',
        options: freqOptions,
      ),
      ProQuestionnaireConfig(
        id: 'poem_7',
        text:
            'Over the last week, on how many days has your skin felt dry or rough?',
        options: freqOptions,
      ),
    ];
  }

  /// Score POEM (0–28) and map to severity band.
  ///
  /// Bands (standard), source Charman CR et al. PMID 15379026:
  /// 0–2 clear/almost clear
  /// 3–7 mild
  /// 8–16 moderate
  /// 17–24 severe
  /// 25–28 very severe
  static (int total, String band) scorePoem(List<int> itemScores) {
    final total = itemScores.fold<int>(0, (a, b) => a + b);
    String band;
    if (total <= 2) {
      band = 'clear / almost clear';
    } else if (total <= 7) {
      band = 'mild eczema';
    } else if (total <= 16) {
      band = 'moderate eczema';
    } else if (total <= 24) {
      band = 'severe eczema';
    } else {
      band = 'very severe eczema';
    }
    return (total, band);
  }

  // ---------------------------------------------------------------------------
  // DLQI (Dermatology Life Quality Index)
  // DLQI development source: Finlay AY, Khan GK. PMID 7945080
  // DLQI MCID (4 points): Shikiar R et al. / EADV consensus
  // DLQI biologic threshold (>= 10): NICE TA and EADV S3 psoriasis guidelines
  // ---------------------------------------------------------------------------

  static List<ProQuestionnaireConfig> dlqiQuestions() {
    const impactOptions = [
      'Not at all',
      'A little',
      'A lot',
      'Very much',
    ];

    return const [
      ProQuestionnaireConfig(
        id: 'dlqi_1',
        text:
            'Over the last week, how itchy, sore, painful or stinging has your skin been?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_2',
        text:
            'Over the last week, how embarrassed or self-conscious have you been alongside your skin?', // Language policy: associative only — no causal claims
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_3',
        text:
            'Over the last week, how much has your skin interfered with going shopping or looking after your home or garden?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_4',
        text:
            'Over the last week, how much has your skin influenced the clothes you wear?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_5',
        text:
            'Over the last week, how much has your skin affected any social or leisure activities?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_6',
        text:
            'Over the last week, how much has your skin made it difficult for you to do any sport?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_7',
        text:
            'Over the last week, has your skin prevented you from working or studying, or made it more difficult?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_8',
        text:
            'Over the last week, how much has your skin created problems with your partner, close friends, or relatives?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_9',
        text:
            'Over the last week, how much has your skin caused any sexual difficulties?',
        options: impactOptions,
      ),
      ProQuestionnaireConfig(
        id: 'dlqi_10',
        text:
            'Over the last week, how much of a problem has the treatment for your skin been (for example, making your home messy, or taking up time)?',
        options: impactOptions,
      ),
    ];
  }

  /// Score DLQI (0–30) and map to impact band.
  ///
  /// Source Finlay AY, Khan GK. PMID 7945080.
  /// Common interpretation:
  /// 0–1: no effect
  /// 2–5: small effect
  /// 6–10: moderate effect
  /// 11–20: very large effect
  /// 21–30: extremely large effect
  static (int total, String band) scoreDlqi(List<int> itemScores) {
    final total = itemScores.fold<int>(0, (a, b) => a + b);
    String band;
    if (total <= 1) {
      band = 'no effect on life';
    } else if (total <= 5) {
      band = 'small effect on life';
    } else if (total <= 10) {
      band = 'moderate effect on life';
    } else if (total <= 20) {
      band = 'very large effect on life';
    } else {
      band = 'extremely large effect on life';
    }
    return (total, band);
  }
}

