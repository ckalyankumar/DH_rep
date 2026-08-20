enum RecommendationPriority { high, medium, low }

/// Self-care: user can act without prescription. Doctor prescribed: needs clinician.
enum RecommendationType { selfCare, doctorPrescribed }

/// Six categories for 20+ self-care recommendations
enum SelfCareCategory {
  lifestyle, // Stress, diet, sleep
  skincare, // Emollients, moisturizers, soak & seal
  triggerAvoidance, // Allergens, irritants, cold/heat, pollution
  behavioral, // Itch-scratch, meditation, adherence
  environmental, // HEPA, bedding, humidifier
  indiaPollution, // AQI, antioxidants, masks (IADVL)
}

extension SelfCareCategoryExtension on SelfCareCategory {
  String get displayLabel {
    switch (this) {
      case SelfCareCategory.lifestyle:
        return 'Lifestyle';
      case SelfCareCategory.skincare:
        return 'Skincare';
      case SelfCareCategory.triggerAvoidance:
        return 'Trigger Avoidance';
      case SelfCareCategory.behavioral:
        return 'Behavioral';
      case SelfCareCategory.environmental:
        return 'Environmental';
      case SelfCareCategory.indiaPollution:
        return 'India Pollution (IADVL)';
    }
  }
}

class Recommendation {
  final int id;
  final String title;
  final String description;
  final RecommendationPriority priority;
  final List<String> tags;
  final String rationale;
  final List<String> steps;
  final String benefits;
  final String evidence;
  final String source;
  final RecommendationType type;
  final SelfCareCategory? selfCareCategory; // When type == selfCare
  final String? pmid; // For CSV export / dermatologist review
  final String? doi; // For CSV export / dermatologist review
  final String? gradeLevel; // For CSV export / dermatologist review
  bool isImplemented;
  bool isSavedForLater;

  Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.tags,
    required this.rationale,
    required this.steps,
    required this.benefits,
    required this.evidence,
    required this.source,
    this.type = RecommendationType.selfCare,
    this.selfCareCategory,
    this.pmid,
    this.doi,
    this.gradeLevel,
    this.isImplemented = false,
    this.isSavedForLater = false,
  });
  
  String getPriorityLabel() {
    switch (priority) {
      case RecommendationPriority.high:
        return 'High';
      case RecommendationPriority.medium:
        return 'Medium';
      case RecommendationPriority.low:
        return 'Low';
    }
  }
}
