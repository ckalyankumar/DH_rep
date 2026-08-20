import 'package:dhealth/services/trigger_normalization_service.dart';

/// User-facing option for a structured trigger.
class TriggerOption {
  final CanonicalTriggerId id;
  final String displayLabel;
  final String? description;

  const TriggerOption({
    required this.id,
    required this.displayLabel,
    this.description,
  });
}

/// Group of trigger options under a top-level category.
class TriggerCategory {
  final String topLevel;
  final String displayLabel;
  final List<TriggerOption> options;

  const TriggerCategory({
    required this.topLevel,
    required this.displayLabel,
    required this.options,
  });
}

/// Default two-level trigger taxonomy for supported conditions.
///
/// Uses the same top-level ids and sub-levels as the trigger normalization
/// lexicon so analytics can continue to use CanonicalTriggerId consistently.
List<TriggerCategory> defaultTriggerTaxonomy(String condition) {
  const baseCategories = [
    TriggerCategory(
      topLevel: 'stress',
      displayLabel: 'Stress',
      options: [
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'stress', subLevel: 'work'),
          displayLabel: 'Work stress',
        ),
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'stress', subLevel: 'general'),
          displayLabel: 'Feeling stressed',
        ),
      ],
    ),
    TriggerCategory(
      topLevel: 'sleep',
      displayLabel: 'Sleep & rest',
      options: [
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'sleep', subLevel: 'late'),
          displayLabel: 'Late night',
        ),
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'sleep', subLevel: 'poor'),
          displayLabel: 'Poor sleep',
        ),
      ],
    ),
    TriggerCategory(
      topLevel: 'diet',
      displayLabel: 'Food & drink',
      options: [
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'diet', subLevel: 'dairy'),
          displayLabel: 'Dairy',
        ),
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'diet', subLevel: 'alcohol'),
          displayLabel: 'Alcohol',
        ),
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'diet', subLevel: 'sugar'),
          displayLabel: 'Sugar / sweets',
        ),
      ],
    ),
    TriggerCategory(
      topLevel: 'environment',
      displayLabel: 'Weather & environment',
      options: [
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'environment', subLevel: 'cold'),
          displayLabel: 'Cold weather',
        ),
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'environment', subLevel: 'heat'),
          displayLabel: 'Hot weather',
        ),
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'environment', subLevel: 'pollution'),
          displayLabel: 'Pollution / smog',
        ),
        TriggerOption(
          id: CanonicalTriggerId(topLevel: 'environment', subLevel: 'pollen'),
          displayLabel: 'Pollen & allergies',
        ),
      ],
    ),
  ];

  final normalized = condition.toLowerCase();

  if (normalized == 'eczema') {
    // 1. Sleep & rest
    // 2. Stress
    // 3. Food & drink
    // 4. Weather & environment
    return [
      baseCategories[1],
      baseCategories[0],
      baseCategories[2],
      baseCategories[3],
    ];
  }

  if (normalized == 'psoriasis') {
    // 1. Stress
    // 2. Weather & environment
    // 3. Food & drink
    // 4. Sleep & rest
    return [
      baseCategories[0],
      baseCategories[3],
      baseCategories[2],
      baseCategories[1],
    ];
  }

  // Default ordering unchanged.
  return baseCategories;
}

