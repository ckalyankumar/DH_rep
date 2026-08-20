import 'package:dhealth/models/daily_wearable_aggregate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Derivation thresholds (adult sleep recommendations; IADVL/NPF guidelines)
// ─────────────────────────────────────────────────────────────────────────────

// Sleep quality thresholds (minutes)
const int kSleepGreat = 420; // >= 7h → quality 5
const int kSleepGood = 360; // >= 6h → quality 4
const int kSleepFair = 300; // >= 5h → quality 3
const int kSleepPoor = 240; // >= 4h → quality 2
// < 4h → quality 1

// Sleep disruption threshold (awakenings)
const int kDisruptionThreshold = 3; // >= 3 awakenings → disrupted = true

// Stress derivation: Garmin deviceStressScore is 0–100, maps to DailyLog 0–10.
// Only applied when deviceStressScore != null.

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Pre-filled check-in values derived from wearable data.
/// Use [WearableCheckinPrefillService.prefill] to create from a [DailyWearableAggregate].
class WearableCheckinPrefill {
  /// Pre-filled check-in values (null = wearable could not supply this field)
  final int? sleepQuality; // 1–5
  final bool? sleepDisruption; // true/false
  final int? stress; // 0–10, only populated for Garmin

  /// Raw wearable values — stored in DailyLog for audit trail
  final double? rawSleepMinutes;
  final int? rawAwakenings;
  final double? rawDeviceStress;

  /// Provenance
  final String provider; // e.g. "fitbit", "garmin"
  final DateTime syncedAt;

  const WearableCheckinPrefill({
    this.sleepQuality,
    this.sleepDisruption,
    this.stress,
    this.rawSleepMinutes,
    this.rawAwakenings,
    this.rawDeviceStress,
    required this.provider,
    required this.syncedAt,
  });

  bool get hasSleepQuality => sleepQuality != null;
  bool get hasSleepDisruption => sleepDisruption != null;
  bool get hasStress => stress != null;

  /// How many fields were actually pre-filled (for post-save summary)
  int get prefillCount =>
      [hasSleepQuality, hasSleepDisruption, hasStress].where((b) => b).length;

  /// Human-readable summary for the UI banner.
  /// e.g. "Fitbit · 6h 12m sleep · 4 awakenings"
  String get summaryLine {
    final parts = <String>[];
    if (rawSleepMinutes != null) {
      final h = rawSleepMinutes! ~/ 60;
      final m = (rawSleepMinutes! % 60).round();
      parts.add('${h}h ${m}m sleep');
    }
    if (rawAwakenings != null) parts.add('$rawAwakenings awakenings');
    return parts.isEmpty
        ? _capitalize(provider)
        : '${_capitalize(provider)} · ${parts.join(' · ')}';
  }
}

/// Pure Dart service: derives check-in prefill values from wearable aggregates.
/// No Firebase, no async, no side effects.
class WearableCheckinPrefillService {
  /// Returns null if aggregate is null or has no usable data.
  WearableCheckinPrefill? prefill(DailyWearableAggregate? aggregate) {
    if (aggregate == null) return null;

    // Rationale: Based on adult sleep recommendations referenced in
    // IADVL/NPF guidelines on sleep and skin inflammation.
    int? sleepQuality;
    if (aggregate.totalSleepMinutes != null) {
      final m = aggregate.totalSleepMinutes!;
      if (m >= kSleepGreat) {
        sleepQuality = 5;
      } else if (m >= kSleepGood) {
        sleepQuality = 4;
      } else if (m >= kSleepFair) {
        sleepQuality = 3;
      } else if (m >= kSleepPoor) {
        sleepQuality = 2;
      } else {
        sleepQuality = 1;
      }
    }

    // Rationale: ≥3 awakenings indicates notable sleep disruption (guideline-based).
    bool? sleepDisruption;
    if (aggregate.awakenings != null) {
      sleepDisruption = aggregate.awakenings! >= kDisruptionThreshold;
    }

    // Rationale: Garmin deviceStressScore (0–100) maps to DailyLog stress (0–10).
    // Do NOT attempt this for any other provider.
    int? stress;
    if (aggregate.deviceStressScore != null) {
      stress = (aggregate.deviceStressScore! / 100 * 10)
          .round()
          .clamp(0, 10);
    }

    // Return null if nothing was derivable (wearable had no useful data today)
    if (sleepQuality == null && sleepDisruption == null && stress == null) {
      return null;
    }

    return WearableCheckinPrefill(
      sleepQuality: sleepQuality,
      sleepDisruption: sleepDisruption,
      stress: stress,
      rawSleepMinutes: aggregate.totalSleepMinutes?.toDouble(),
      rawAwakenings: aggregate.awakenings,
      rawDeviceStress: aggregate.deviceStressScore,
      provider: aggregate.provider.name,
      syncedAt: aggregate.syncedAt,
    );
  }
}
