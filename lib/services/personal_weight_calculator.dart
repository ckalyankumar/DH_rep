import 'package:dhealth/config/risk_score_config.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/personal_weight_profile.dart';
import 'package:dhealth/services/insight_engine.dart';

/// Computes patient-specific weight profiles from 90-day correlation data.
///
/// Deterministic: correlates stress, sleep, mood with itch+severity outcome,
/// then maps correlations to weights. No ML.
class PersonalWeightCalculator {
  static const _minDataDays = 30;
  static const _maxDataDays = 90;
  static const _maxLagDays = 7;

  /// Compute personal weight profile from logs. Returns null if insufficient data.
  ///
  /// [logs] - typically last 90 days, sorted by date ascending
  /// [disorderDefaults] - disorder-specific default weights to blend with
  /// [wearableAggregates] - optional wearable data for HRV/sleep correlation
  static PersonalWeightProfile? computePersonalWeightProfile(
    List<DailyLog> logs,
    RiskScoreWeights disorderDefaults, {
    List<DailyWearableAggregate>? wearableAggregates,
  }) {
    if (logs.length < _minDataDays) return null;

    final sorted = List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
    final window = sorted.length > _maxDataDays
        ? sorted.sublist(sorted.length - _maxDataDays)
        : sorted;
    final dataDays = window.length;

    // Outcome metric: itch + severity proxy (higher = worse)
    final outcomeSeries = window.map((l) => _outcomeMetric(l)).toList();
    // WEARABLE ADDITION: prefer objective wearable values when available
    final stressSeries = window.map((l) => _stressValue(l)).toList();
    final sleepSeries = window.map((l) => _sleepValue(l)).toList();
    final moodSeries = window.map((l) => (5 - l.mood).toDouble()).toList();

    // Best absolute correlation per factor (with lag)
    final stressCorr = _bestLagCorrelation(stressSeries, outcomeSeries);
    final sleepCorr = _bestLagCorrelation(sleepSeries, outcomeSeries);
    final moodCorr = _bestLagCorrelation(moodSeries, outcomeSeries);

    // Target sum for personalizable components (stress + mood + sleep)
    final targetSum = disorderDefaults.stressWeight +
        disorderDefaults.moodWeight +
        disorderDefaults.sleepWeight;

    // Map correlations to weights: proportional to |corr|, with floor for zero
    const epsilon = 0.01;
    final absStress = stressCorr.abs() + epsilon;
    final absSleep = sleepCorr.abs() + epsilon;
    final absMood = moodCorr.abs() + epsilon;
    final total = absStress + absSleep + absMood;

    double personalStress = (absStress / total) * targetSum;
    double personalSleep = (absSleep / total) * targetSum;
    double personalMood = (absMood / total) * targetSum;

    // Blend factor: more data = more personal, less = more default
    double blendFactor;
    if (dataDays >= 90) {
      blendFactor = 1.0;
    } else if (dataDays >= 60) {
      blendFactor = 0.7;
    } else if (dataDays >= 45) {
      blendFactor = 0.5;
    } else {
      blendFactor = 0.3;
    }

    // Blend with disorder default
    double stressWeight = blendFactor * personalStress +
        (1 - blendFactor) * disorderDefaults.stressWeight;
    double moodWeight = blendFactor * personalMood +
        (1 - blendFactor) * disorderDefaults.moodWeight;
    double sleepWeight = blendFactor * personalSleep +
        (1 - blendFactor) * disorderDefaults.sleepWeight;
    double hrvWeight = 0;

    // WEARABLE ADDITION: extend weights from wearable correlation if sufficient data
    if (wearableAggregates != null && wearableAggregates.length >= 14) {
      final aggByDate = {for (final a in wearableAggregates) a.date: a};
      String formatDate(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final hrvSeries = <double>[];
      final sleepSeries = <double>[];
      final itchSeries = <double>[];
      var sleepDays = 0;

      for (final log in window) {
        final dateStr = formatDate(log.date);
        final agg = aggByDate[dateStr];
        itchSeries.add(_outcomeMetric(log).toDouble());
        if (agg?.hrvNightly != null) {
          hrvSeries.add(agg!.hrvNightly!);
        } else {
          hrvSeries.add(0);
        }
        if (agg?.totalSleepMinutes != null) {
          sleepSeries.add(agg!.totalSleepMinutes!.toDouble());
          sleepDays++;
        } else {
          sleepSeries.add(0);
        }
      }

      if (hrvSeries.any((v) => v > 0)) {
        double bestHrvCorr = 0;
        for (var lag = 0; lag <= 2 && lag < window.length; lag++) {
          final causeLagged = hrvSeries.sublist(0, hrvSeries.length - lag);
          final effectShifted = itchSeries.sublist(lag);
          final valid = <int>[];
          for (var i = 0; i < causeLagged.length; i++) {
            if (causeLagged[i] > 0) valid.add(i);
          }
          if (valid.length < 5) continue;
          final cx = valid.map((i) => causeLagged[i]).toList();
          final ex = valid.map((i) => effectShifted[i]).toList();
          final r = InsightEngine.calculateSpearman(cx, ex);
          if (r.abs() > bestHrvCorr.abs()) bestHrvCorr = r;
        }
        if (bestHrvCorr.abs() > 0.45) {
          const epsilon = 0.01;
          final absHrv = bestHrvCorr.abs() + epsilon;
          final totalWithHrv = absStress + absSleep + absMood + absHrv;
          final personalHrv = (absHrv / totalWithHrv) * targetSum;
          final personalStress4 = (absStress / totalWithHrv) * targetSum;
          final personalMood4 = (absMood / totalWithHrv) * targetSum;
          final personalSleep4 = (absSleep / totalWithHrv) * targetSum;
          hrvWeight = blendFactor * personalHrv;
          stressWeight = blendFactor * personalStress4 + (1 - blendFactor) * disorderDefaults.stressWeight;
          moodWeight = blendFactor * personalMood4 + (1 - blendFactor) * disorderDefaults.moodWeight;
          sleepWeight = blendFactor * personalSleep4 + (1 - blendFactor) * disorderDefaults.sleepWeight;
        }
      }

      if (sleepSeries.any((v) => v > 0) && sleepDays >= window.length * 0.6) {
        final valid = <int>[];
        for (var i = 0; i < sleepSeries.length; i++) {
          if (sleepSeries[i] > 0) valid.add(i);
        }
        if (valid.length >= 10) {
          final sx = valid.map((i) => sleepSeries[i]).toList();
          final ix = valid.map((i) => itchSeries[i]).toList();
          final sleepCorr = InsightEngine.calculateSpearman(sx, ix);
          if (sleepCorr.abs() > 0.45) {
            sleepWeight = (sleepWeight + 0.2).clamp(0, disorderDefaults.sleepWeight + 2);
          }
        }
      }
    }

    return PersonalWeightProfile(
      stressWeight: stressWeight,
      moodWeight: moodWeight,
      sleepWeight: sleepWeight,
      blendFactor: blendFactor,
      dataDaysUsed: dataDays,
      isFromCorrelation: true,
      hrvWeight: hrvWeight,
    );
  }

  static double _outcomeMetric(DailyLog log) {
    var s = log.itchIntensity.toDouble();
    switch (log.lesionSeverity.toLowerCase()) {
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
    return s;
  }

  /// Returns the correlation (possibly at best lag) with highest absolute value.
  static double _bestLagCorrelation(List<double> cause, List<double> effect) {
    if (cause.length != effect.length || cause.length < 3) return 0.0;

    final lagResults = InsightEngine.calculateLagCorrelation(
      cause,
      effect,
      maxLag: _maxLagDays,
    );

    double best = 0.0;
    lagResults.forEach((_, corr) {
      if (corr.abs() > best.abs()) best = corr;
    });

    return best;
  }

  // WEARABLE ADDITION
  // Prefer objective wearable sleep minutes when available.
  // Raw minutes (0–480+) normalised to 0.0–1.0 is higher precision
  // than the recalled 1–5 manual scale.
  static double _sleepValue(DailyLog log) {
    if (log.wearableRawSleepMinutes != null) {
      return (log.wearableRawSleepMinutes! / 480.0).clamp(0.0, 1.0);
    }
    // Fallback: manual score normalised to 0–1
    return (log.sleepQuality - 1) / 4.0;
  }

  // WEARABLE ADDITION
  // Prefer Garmin device stress score when available AND not overridden by user.
  // If user overrode the pre-filled stress, their manual value is more reliable.
  static double _stressValue(DailyLog log) {
    if (log.wearableRawDeviceStress != null && !log.stressWasOverridden) {
      return log.wearableRawDeviceStress! / 100.0;
    }
    return log.stressLevel / 10.0;
  }

  // TODO (WEARABLE ADDITION): apply _dataPointWeight() once weighted
  // Spearman is implemented.
  // Wearable-sourced, non-overridden data points are more reliable
  // than recalled values. Apply a 1.2x weight multiplier.
  // ignore: unused_element
  static double _dataPointWeight(DailyLog log) {
    final hasPrefill = log.hasWearablePrefill;
    final notOverridden = !log.sleepQualityWasOverridden &&
        !log.sleepDisruptionWasOverridden;
    return (hasPrefill && notOverridden) ? 1.2 : 1.0;
  }
}
