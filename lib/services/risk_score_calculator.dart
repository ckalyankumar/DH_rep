import 'dart:convert';
import 'dart:io';

import 'package:dhealth/config/risk_score_config.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/personal_weight_profile.dart';
import 'package:dhealth/models/risk_score_result.dart';
import 'package:dhealth/services/insight_engine.dart';

/// Wearable-derived risk modifier. Computed from today's DailyWearableAggregate.
class WearableRiskModifier {
  final int modifier;

  const WearableRiskModifier(this.modifier);

  /// Compute modifier from aggregate. Cap total at +15.
  static WearableRiskModifier? fromAggregate(DailyWearableAggregate? agg) {
    if (agg == null) return null;
    var total = 0;
    final hrv = agg.hrvNightly;
    if (hrv != null) {
      if (hrv < 35) {
        total += 8;
      } else if (hrv < 45) {
        total += 4;
      }
    }
    final sleep = agg.totalSleepMinutes;
    if (sleep != null) {
      if (sleep < 300) {
        total += 6;
      } else if (sleep < 360) {
        total += 3;
      }
    }
    if ((agg.awakenings ?? 0) >= 3) total += 4;
    final steps = agg.steps;
    if (steps != null && steps < 3000) total += 3;
    total = total.clamp(0, 15);
    return WearableRiskModifier(total);
  }
}

/// Deterministic, explainable risk score (0–100) for psoriasis and eczema.
///
/// Components: itch, lesion severity/extent, stress, mood, sleep, env.
/// Modifiers: short-term trend, InsightEngine trigger correlations.
/// Red-flag override from guidelines forces urgent band.
class RiskScoreCalculator {
  /// Calculate risk score from logs and optional context.
  ///
  /// [logs] - sorted by date ascending (oldest first)
  /// [condition] - 'psoriasis' or 'eczema'
  /// [disorder] - from DisorderRegistry
  /// [envData] - optional { weather: { main: { temp, humidity } } }
  /// [detectedTriggers] - optional from InsightEngine.identifyTriggers
  /// [personalProfile] - optional patient-specific weights from 90-day correlation
  /// [wearableRiskModifier] - optional modifier from today's wearable data
  static RiskScoreResult calculate({
    required List<DailyLog> logs,
    required String condition,
    required ClinicalDisorder disorder,
    Map<String, dynamic>? envData,
    List<EvidencedTrigger>? detectedTriggers,
    PersonalWeightProfile? personalProfile,
    WearableRiskModifier? wearableRiskModifier,
  }) {
    // #region agent log
    try {
      final logFile = File('debug-4d8c79.log');
      final logEntry = <String, dynamic>{
        'sessionId': '4d8c79',
        'runId': 'pre-fix',
        'hypothesisId': 'RISK-A',
        'location': 'risk_score_calculator.dart:calculate',
        'message': 'calculate_enter',
        'data': {
          'logCount': logs.length,
          'condition': condition,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      logFile.writeAsStringSync(
        '${jsonEncode(logEntry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // #endregion

    final disorderWeights = _getWeights(condition);
    final weights = personalProfile != null
        ? personalProfile.mergeInto(disorderWeights)
        : disorderWeights;
    final explanation = <String>[];

    // 1. Base components from most recent log
    DailyLog? latestLog;
    if (logs.isNotEmpty) {
      final sorted = List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
      latestLog = sorted.last;
    }

    final components = <String, double>{};
    if (latestLog != null) {
      components['itch'] = _itchComponent(latestLog.itchIntensity, weights.itchWeight);
      components['lesion'] = _lesionComponent(latestLog.lesionSeverity, weights.lesionWeight);
      components['extent'] = _extentComponent(latestLog.affectedAreas.length, weights.extentWeight);
      components['stress'] = _stressComponent(latestLog.stressLevel, weights.stressWeight);
      components['mood'] = _moodComponent(latestLog.mood, weights.moodWeight);
      components['sleep'] = _sleepComponent(
        latestLog.sleepQuality,
        latestLog.sleepDisruption,
        weights.sleepWeight,
      );
      components['env'] = _envComponent(envData, weights.envWeight);
    } else {
      components['itch'] = 0;
      components['lesion'] = 0;
      components['extent'] = 0;
      components['stress'] = 0;
      components['mood'] = 0;
      components['sleep'] = 0;
      components['env'] = 0;
    }

    double baseScore = components.values.fold(0, (a, b) => a + b);

    // 2. Short-term trend: worsening in last 3–7 days adds modifier
    double trendMod = 0;
    if (logs.length >= 7) {
      final sorted = List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
      final last3 = sorted.sublist(sorted.length - 3);
      final prior4 = sorted.sublist(sorted.length - 7, sorted.length - 3);
      final last3Avg = _trendMetric(last3);
      final prior4Avg = _trendMetric(prior4);
      if (last3Avg > prior4Avg + 1.5) {
        trendMod = ((last3Avg - prior4Avg) * 3).clamp(0, trendModifierMax);
        explanation.add('Recent worsening trend adds +${trendMod.toStringAsFixed(0)}');
      }

      // #region agent log
      try {
        final logFile = File('debug-4d8c79.log');
        final logEntry = <String, dynamic>{
          'sessionId': '4d8c79',
          'runId': 'pre-fix',
          'hypothesisId': 'RISK-B',
          'location': 'risk_score_calculator.dart:calculate',
          'message': 'trend_block_evaluated',
          'data': {
            'sortedLen': sorted.length,
            'trendMod': trendMod,
            'last3Avg': last3Avg,
            'prior4Avg': prior4Avg,
          },
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        logFile.writeAsStringSync(
          '${jsonEncode(logEntry)}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
    }

    baseScore += trendMod;

    // 3. Trigger modifier: detected triggers + elevated current metric
    double triggerMod = 0;
    if (detectedTriggers != null && latestLog != null) {
      for (final t in detectedTriggers.take(3)) {
        final name = t.name.toLowerCase();
        double currentMetric = 0;
        double threshold = 0.5;
        if (name.contains('stress') || name.contains('psychological')) {
          currentMetric = latestLog.stressLevel / 10;
          threshold = 0.6;
        } else if (name.contains('sleep') || name.contains('deprivation')) {
          currentMetric = 1 - (latestLog.sleepQuality / 5);
          if (latestLog.sleepDisruption) currentMetric = 1.0;
          threshold = 0.5;
        } else if (name.contains('mood') || name.contains('depression')) {
          currentMetric = 1 - (latestLog.mood / 5);
          threshold = 0.5;
        }
        if (currentMetric >= threshold && t.confidence >= 50) {
          triggerMod += (t.confidence / 100) * (triggerModifierMax / 3);
        }
      }
      triggerMod = triggerMod.clamp(0, triggerModifierMax);
      if (triggerMod > 0) {
        explanation.add('Elevated trigger factors add +${triggerMod.toStringAsFixed(0)}');
      }
    }

    baseScore += triggerMod;

    // WEARABLE ADDITION: apply wearable modifier after trend/trigger, before red-flag
    int wearableMod = 0;
    if (wearableRiskModifier != null) {
      wearableMod = wearableRiskModifier.modifier;
      if (wearableMod > 0) {
        explanation.add('Wearable data adds +$wearableMod');
      }
    }
    baseScore += wearableMod;

    // 4. Red-flag override
    final redFlags = logs.isNotEmpty
        ? InsightEngine.detectRedFlags(logs, disorder)
        : <RedFlag>[];
    final hasRedFlag = redFlags.isNotEmpty;

    int finalScore;
    String band;

    if (hasRedFlag) {
      finalScore = baseScore < redFlagOverrideMinScore
          ? redFlagOverrideMinScore
          : baseScore.round().clamp(0, 100);
      band = redFlagOverrideBand;
      explanation.add('Guideline red flag detected → urgent band');
    } else {
      finalScore = baseScore.round().clamp(0, 100);
      band = RiskScoreResult.scoreToBand(finalScore);
    }

    return RiskScoreResult(
      finalScore: finalScore,
      band: band,
      components: components,
      trendModifier: trendMod,
      triggerModifier: triggerMod,
      redFlagOverride: hasRedFlag,
      explanation: explanation,
      usedPersonalWeights: personalProfile != null,
      wearableModifier: wearableMod,
    );
  }

  static RiskScoreWeights _getWeights(String condition) {
    switch (condition.toLowerCase()) {
      case 'psoriasis':
        return psoriasisRiskWeights;
      case 'eczema':
      case 'atopic dermatitis':
      case 'ad':
        return eczemaRiskWeights;
      default:
        return psoriasisRiskWeights;
    }
  }

  static double _itchComponent(int itch, double weight) {
    return (itch / 10) * weight;
  }

  static double _lesionComponent(String severity, double weight) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return weight;
      case 'moderate':
        return weight * 0.7;
      case 'mild':
        return weight * 0.4;
      default:
        return 0;
    }
  }

  static double _extentComponent(int areaCount, double weight) {
    final capped = areaCount.clamp(0, 5);
    return (capped / 5) * weight;
  }

  static double _stressComponent(int stress, double weight) {
    return (stress / 10) * weight;
  }

  static double _moodComponent(int mood, double weight) {
    final inverted = 5 - mood;
    return (inverted / 4) * weight;
  }

  static double _sleepComponent(int quality, bool disruption, double weight) {
    var score = ((5 - quality) / 4) * (weight * 0.7);
    if (disruption) score += weight * 0.3;
    return score.clamp(0, weight);
  }

  static double _envComponent(Map<String, dynamic>? envData, double weight) {
    if (envData == null) return 0;
    try {
      final weather = envData['weather'] as Map<String, dynamic>?;
      if (weather == null) return 0;
      final main = weather['main'] as Map<String, dynamic>?;
      if (main == null) return 0;
      final temp = (main['temp'] as num?)?.toDouble();
      final humidity = (main['humidity'] as num?)?.toDouble();
      if (temp == null) return 0;

      double mod = 0;
      if (temp < 10 && (humidity == null || humidity < 40)) {
        mod = weight * 0.8; // Cold + dry: psoriasis/eczema risk
      } else if (temp < 5) {
        mod = weight * 0.5;
      }
      return mod;
    } catch (_) {
      return 0;
    }
  }

  /// Metric for trend: itch + severity proxy (higher = worse)
  static double _trendMetric(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    double sum = 0;
    for (final l in logs) {
      var s = l.itchIntensity.toDouble();
      switch (l.lesionSeverity.toLowerCase()) {
        case 'severe':
          s += 4;
          break;
        case 'moderate':
          s += 2;
          break;
        case 'mild':
          s += 1;
          break;
      }
      sum += s;
    }
    return sum / logs.length;
  }
}
