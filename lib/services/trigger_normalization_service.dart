import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/config/trigger_taxonomy.dart';

/// Canonical trigger identifier with two-level hierarchy.
///
/// - topLevel: broad category used for analytics ('stress', 'sleep', 'diet')
/// - subLevel: optional sub-category for display ('work', 'late', 'dairy')
class CanonicalTriggerId {
  final String topLevel;
  final String? subLevel;

  const CanonicalTriggerId({
    required this.topLevel,
    this.subLevel,
  });

  String get full => subLevel == null ? topLevel : '$topLevel.$subLevel';
}

/// One normalized trigger instance with confidence score.
class NormalizedTrigger {
  final CanonicalTriggerId id;
  final double confidence; // 0.0–1.0

  const NormalizedTrigger({
    required this.id,
    required this.confidence,
  });
}

class _TriggerLexiconEntry {
  final CanonicalTriggerId id;
  final List<String> keywords; // ordered by specificity

  const _TriggerLexiconEntry(this.id, this.keywords);
}

/// Lightweight lexicon for mapping free-text trigger notes into canonical ids.
///
/// NOTE: This is intentionally compact and can be extended over time.
const List<_TriggerLexiconEntry> _triggerLexicon = [
  // Stress
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'stress', subLevel: 'work'),
    ['work stress', 'office stress', 'deadline'],
  ),
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'stress', subLevel: 'general'),
    ['very stressed', 'stressed', 'stress'],
  ),

  // Sleep
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'sleep', subLevel: 'late'),
    ['late night', 'slept late', 'midnight', 'sleep late'],
  ),
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'sleep', subLevel: 'poor'),
    ['poor sleep', 'bad sleep', 'insomnia'],
  ),

  // Diet
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'diet', subLevel: 'dairy'),
    ['cheese', 'yogurt', 'milk', 'dairy'],
  ),
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'diet', subLevel: 'alcohol'),
    ['alcohol', 'wine', 'beer'],
  ),
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'diet', subLevel: 'sugar'),
    ['sugar', 'sweets', 'dessert', 'chocolate'],
  ),

  // Environment
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'environment', subLevel: 'cold'),
    ['cold weather', 'cold air', 'winter'],
  ),
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'environment', subLevel: 'heat'),
    ['hot weather', 'heat', 'summer'],
  ),
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'environment', subLevel: 'pollution'),
    ['pollution', 'smog'],
  ),
  _TriggerLexiconEntry(
    CanonicalTriggerId(topLevel: 'environment', subLevel: 'pollen'),
    ['pollen', 'allergy season'],
  ),
];

const List<String> _negationPhrases = [
  'no ',
  'not ',
  'avoided ',
  'without ',
  'cut out ',
];

String _preprocess(String raw) {
  var s = raw.toLowerCase().trim();
  // Replace common punctuation with spaces.
  s = s.replaceAll(RegExp(r'[.,!?;:]'), ' ');
  // Collapse multiple spaces.
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s;
}

bool _isNegated(String text, String keyword) {
  // Simple heuristic: look for "no <keyword>", "avoided <keyword>", etc.
  for (final neg in _negationPhrases) {
    final pattern = '$neg$keyword';
    if (text.contains(pattern)) return true;
  }
  return false;
}

double _matchConfidence(String text, String keyword) {
  if (text == keyword) return 1.0;
  // Exact word match
  final tokens = text.split(' ');
  if (tokens.contains(keyword)) return 0.9;
  if (text.contains(keyword)) {
    final ratio = keyword.length / text.length;
    if (ratio >= 0.5) return 0.8;
    if (ratio >= 0.3) return 0.6;
  }
  return 0.0;
}

/// Normalize a list of raw trigger strings into canonical ids with confidence.
///
/// This does NOT mutate or persist anything; it is safe to use at read-time
/// for analytics such as trigger–PRO correlation.
List<NormalizedTrigger> normalizeTriggers(List<String>? rawTriggers) {
  if (rawTriggers == null || rawTriggers.isEmpty) return const [];

  final results = <NormalizedTrigger>[];

  for (final raw in rawTriggers) {
    final text = _preprocess(raw);
    if (text.isEmpty) continue;

    final matches = <NormalizedTrigger>[];

    for (final entry in _triggerLexicon) {
      for (final kw in entry.keywords) {
        final kwNorm = _preprocess(kw);
        if (!text.contains(kwNorm)) continue;
        if (_isNegated(text, kwNorm)) continue;
        final conf = _matchConfidence(text, kwNorm);
        if (conf <= 0.0) continue;
        matches.add(NormalizedTrigger(id: entry.id, confidence: conf));
      }
    }

    if (matches.isEmpty) {
      // Unmapped triggers are not discarded; they can be counted separately
      // by a background process using the raw `triggers` field.
      continue;
    }

    // Keep only matches that are close to the best confidence for this string.
    final best = matches.map((m) => m.confidence).fold<double>(0.0, (a, b) => a > b ? a : b);
    final filtered = matches
        .where((m) => m.confidence >= best * 0.8 && m.confidence >= 0.6)
        .toList();

    results.addAll(filtered);
  }

  return results;
}

/// Convenience helper for extracting top-level categories per log.
///
/// Returns a set of top-level ids (e.g. 'stress', 'sleep') for a given log.
Set<String> topLevelTriggersForLog(DailyLog log) {
  final result = <String>{};

  // Step 1 — structured path (new logs)
  final structuredIds = log.structuredTriggerIds;
  if (structuredIds != null && structuredIds.isNotEmpty) {
    for (final id in structuredIds) {
      final parts = id.split('.');
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        result.add(parts.first);
      }
    }
  }

  // Step 2 — free-text path
  final rawTriggers = log.triggers;
  if (rawTriggers != null && rawTriggers.isNotEmpty) {
    // Build a set of all structured display labels for this condition.
    final taxonomy = defaultTriggerTaxonomy(log.condition);
    final structuredLabels = <String>{};
    for (final category in taxonomy) {
      for (final option in category.options) {
        structuredLabels.add(option.displayLabel);
      }
    }

    // Free-text entries are those not matching any structured display label.
    final freeText = rawTriggers
        .where((label) => !structuredLabels.contains(label))
        .toList();

    if (freeText.isNotEmpty) {
      final normalizedFreeText = normalizeTriggers(freeText);
      result.addAll(
        normalizedFreeText.map((n) => n.id.topLevel),
      );
    } else if (structuredIds == null || structuredIds.isEmpty) {
      // Legacy behaviour: for old logs with only structured labels in `triggers`
      // but no `structuredTriggerIds`, normalize all triggers.
      final normalizedAll = normalizeTriggers(rawTriggers);
      result.addAll(
        normalizedAll.map((n) => n.id.topLevel),
      );
    }
  }

  return result;
}

