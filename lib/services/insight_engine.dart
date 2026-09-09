import 'dart:math';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/log_density_confidence.dart';
import 'package:dhealth/services/risk_score_calculator.dart';
import 'package:dhealth/services/trigger_normalization_service.dart';
import 'package:dhealth/services/insight_models.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// CLINICAL INSIGHTS ENGINE - EVIDENCE-BACKED & PEER-REVIEWED
///
/// ⚠️ MEDICAL DISCLAIMER:
/// This engine generates statistical insights based on personal health data
/// ONLY. Results are NOT medical diagnoses or treatment recommendations.
/// Always consult a dermatologist before making treatment changes.
/// ═══════════════════════════════════════════════════════════════════════

class InsightEngine {
  // Minimum data points for statistical confidence
  static const _minLogsForInsights = 10;
  static const _minLogsForPatterns = 14;
  static const _minLogsForRiskPrediction = 7;
  static const _correlationThreshold =
      0.55; // Pearson r effect-size floor for "significant" correlation
  static const _maxLagDays = 7; // Maximum lag to test (7 days)

  /// Minimum paired observations required before a (possibly lagged) Pearson r
  /// is eligible. n=3 is enough to *compute* r but the estimate is too noisy
  /// to choose a "best lag" from; n≥10 is a common rule of thumb for a
  /// stable Pearson coefficient (see e.g. Bonett & Wright 2000).
  static const minPointsForLagCorrelation = 10;

  /// 1. PEARSON CORRELATION: Statistical relationship between two variables
  /// Returns correlation coefficient from -1.0 (perfect inverse) to 1.0 (perfect positive)
  static double calculateCorrelation(List<num> x, List<num> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    // fold<double>: callers often pass List<double>, and List.reduce then
    // requires (double, double) => double. A (num, num) => num lambda fails
    // at runtime.
    final meanX = x.fold<double>(0, (sum, v) => sum + v.toDouble()) / x.length;
    final meanY = y.fold<double>(0, (sum, v) => sum + v.toDouble()) / y.length;

    // Calculate Pearson correlation coefficient
    double numerator = 0;
    double denomX = 0;
    double denomY = 0;

    for (int i = 0; i < x.length; i++) {
      final dx = (x[i] - meanX).toDouble();
      final dy = (y[i] - meanY).toDouble();
      numerator += dx * dy;
      denomX += dx * dx;
      denomY += dy * dy;
    }

    final denominator = sqrt(denomX * denomY);
    if (denominator == 0) return 0.0;

    return (numerator / denominator).clamp(-1.0, 1.0);
  }

  /// Spearman rank correlation (non-parametric).
  ///
  /// Converts x and y to ranks and then applies Pearson correlation.
  static double calculateSpearman(List<num> x, List<num> y) {
    if (x.length != y.length || x.length < 2) return 0.0;

    List<double> ranks0(List<num> values) {
      final indexed = List.generate(
        values.length,
        (i) => MapEntry(i, values[i].toDouble()),
      );
      indexed.sort((a, b) => a.value.compareTo(b.value));

      final ranks = List<double>.filled(values.length, 0);
      int i = 0;
      while (i < indexed.length) {
        int j = i;
        while (j + 1 < indexed.length &&
            indexed[j + 1].value == indexed[i].value) {
          j++;
        }
        final rank = (i + j + 2) / 2.0; // average rank, 1-based
        for (int k = i; k <= j; k++) {
          ranks[indexed[k].key] = rank;
        }
        i = j + 1;
      }
      return ranks;
    }

    final rx = ranks0(x);
    final ry = ranks0(y);
    return calculateCorrelation(rx, ry);
  }

  /// 2. LAG CORRELATION: Detects delayed relationships
  /// E.g., "Itch increases 2 days after high stress"
  /// Returns map of {lag_days: correlation_coefficient}
  ///
  /// A lag is omitted unless at least [minPointsForLagCorrelation] paired
  /// observations remain after the shift. Callers that pick the "best" lag
  /// must still apply [bestSignificantLag] so the 8-test search is
  /// Bonferroni-corrected.
  static Map<int, double> calculateLagCorrelation(
    List<num> cause,
    List<num> effect, {
    int maxLag = 7,
  }) {
    final results = <int, double>{};

    for (int lag = 0; lag <= maxLag && lag < cause.length; lag++) {
      if (effect.length <= lag) break;

      final causeLagged = cause.sublist(0, cause.length - lag);
      final effectShifted = effect.sublist(lag);

      if (causeLagged.length >= minPointsForLagCorrelation) {
        results[lag] = calculateCorrelation(
          causeLagged.cast<num>(),
          effectShifted.cast<num>(),
        );
      }
    }

    return results;
  }

  /// Bonferroni-adjusted critical |r| via Fisher's z-transform.
  ///
  /// Method: Dunn–Bonferroni correction of a two-sided Pearson test, with
  /// the critical value obtained from Fisher's z (Fisher 1921). For K
  /// simultaneous lag tests and family-wise α = 0.05:
  ///
  ///   α' = α / K
  ///   z* = Φ^{-1}(1 − α'/2)
  ///   r_crit = tanh( z* / sqrt(n − 3) )
  ///
  /// n is the number of paired observations at that lag. K is the number of
  /// lags actually tested (eligible under [minPointsForLagCorrelation]), not
  /// a fixed 8 — that is the valid Bonferroni count.
  ///
  /// z* values are standard-normal quantiles (NIST / common z-tables).
  static double bonferroniCriticalAbsR({
    required int n,
    required int lagCount,
  }) {
    if (n < 4 || lagCount < 1) return 1.0;
    final z = _bonferroniZCrit(lagCount);
    return _tanh(z / sqrt(n - 3));
  }

  /// Among [lagResults], return the (lag, r) with largest |r| that clears
  /// both the Bonferroni critical |r| for its remaining n and an optional
  /// effect-size floor [minAbsR]. Returns null if none qualify.
  static ({int lag, double r})? bestSignificantLag(
    Map<int, double> lagResults, {
    required int seriesLength,
    double minAbsR = 0.0,
  }) {
    if (lagResults.isEmpty) return null;
    final k = lagResults.length;
    ({int lag, double r})? best;
    for (final entry in lagResults.entries) {
      final n = seriesLength - entry.key;
      final crit = bonferroniCriticalAbsR(n: n, lagCount: k);
      final threshold = max(minAbsR, crit);
      if (entry.value.abs() > threshold) {
        if (best == null || entry.value.abs() > best.r.abs()) {
          best = (lag: entry.key, r: entry.value);
        }
      }
    }
    return best;
  }

  /// 3. TRIGGER IDENTIFICATION: Evidence-backed detection with mechanisms
  /// Maps user data to disorder registry triggers and calculates confidence
  static List<EvidencedTrigger> identifyTriggers(
    List<DailyLog> logs,
    String condition,
    ClinicalDisorder disorder,
  ) {
    if (logs.length < _minLogsForInsights) return [];

    final sorted = _sortedByDateAscending(logs);
    final detectedTriggers = <EvidencedTrigger>[];
    final itchIntensities =
        sorted.map((l) => l.itchIntensity.toDouble()).toList();

    for (final registryTrigger in disorder.triggers) {
      final mapping = metricMappingForTrigger(registryTrigger.name, sorted);
      if (mapping == null || mapping.series.isEmpty) continue;

      final lagResults = calculateLagCorrelation(
        mapping.series,
        itchIntensities,
        maxLag: _maxLagDays,
      );

      final best = bestSignificantLag(
        lagResults,
        seriesLength: mapping.series.length,
        minAbsR: _correlationThreshold,
      );
      if (best == null) continue;

      final absR = best.r.abs();
      detectedTriggers.add(
        EvidencedTrigger(
          name: registryTrigger.name,
          mechanism: registryTrigger.mechanism,
          baselineIncidence: registryTrigger.baselineIncidence,
          symptoms: registryTrigger.symptoms,
          preventionStrategy: registryTrigger.preventionStrategy,
          expectedImprovement: registryTrigger.expectedImprovement,
          evidence: registryTrigger.evidence,
          lagDays: best.lag,
          correlation: absR,
          confidence: min(100.0, absR * 100.0),
          coverageNote: mapping.coverageNote,
        ),
      );
    }

    detectedTriggers.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detectedTriggers;
  }

  /// 4. PATTERN DETECTION: Find recurring weekly or temporal patterns
  static List<PatternInsight> detectPatterns(List<DailyLog> logs) {
    if (logs.length < _minLogsForPatterns) return [];

    final sorted = _sortedByDateAscending(logs);
    final patterns = <PatternInsight>[];

    // Group by day of week
    final byDayOfWeek = <int, List<int>>{};
    for (final log in sorted) {
      final dayOfWeek = log.date.weekday;
      if (!byDayOfWeek.containsKey(dayOfWeek)) {
        byDayOfWeek[dayOfWeek] = [];
      }
      byDayOfWeek[dayOfWeek]!.add(log.itchIntensity);
    }

    // Check for weekly pattern
    if (byDayOfWeek.length >= 5) {
      final avgByDay = <int, double>{};
      byDayOfWeek.forEach((day, values) {
        avgByDay[day] = values.reduce((a, b) => a + b) / values.length;
      });

      final maxDay =
          avgByDay.entries.reduce((a, b) => a.value > b.value ? a : b);
      final minDay =
          avgByDay.entries.reduce((a, b) => a.value < b.value ? a : b);
      final variance = maxDay.value - minDay.value;

      if (variance > 2.5) {
        patterns.add(
          PatternInsight(
            pattern: 'Weekly Cycle Detected',
            description:
                'Symptoms peak on ${_getDayName(maxDay.key)} (${maxDay.value.toStringAsFixed(1)}/10) and improve on ${_getDayName(minDay.key)} (${minDay.value.toStringAsFixed(1)}/10)',
            confidence: 0.75,
            occurrences:
                sorted.where((l) => l.date.weekday == maxDay.key).length,
            predictability: 'High',
          ),
        );
      }
    }

    // Detect temporal trends (improving vs worsening over time)
    if (sorted.length >= 14) {
      final firstHalf = sorted.sublist(0, (sorted.length / 2).toInt());
      final secondHalf = sorted.sublist((sorted.length / 2).toInt());

      final firstHalfAvg =
          firstHalf.map((l) => l.itchIntensity).reduce((a, b) => a + b) /
              firstHalf.length;

      final secondHalfAvg =
          secondHalf.map((l) => l.itchIntensity).reduce((a, b) => a + b) /
              secondHalf.length;

      final difference = (secondHalfAvg - firstHalfAvg).abs();

      if (difference > 1.5) {
        final trend = secondHalfAvg > firstHalfAvg ? 'Worsening' : 'Improving';

        patterns.add(
          PatternInsight(
            pattern: 'Overall $trend Trend',
            description:
                'Itch levels are $trend over time: ${firstHalfAvg.toStringAsFixed(1)}/10 → ${secondHalfAvg.toStringAsFixed(1)}/10',
            confidence: 0.70,
            occurrences: secondHalf.length,
            predictability: 'Medium',
          ),
        );
      }
    }

    return patterns;
  }

  /// 5. STREAK CALCULATION: Track consecutive good days for motivation
  static StreakInfo calculateStreaks(
    List<DailyLog> logs, {
    int goodDayThreshold = 4, // Itch <= 4 is a "good day"
  }) {
    if (logs.isEmpty) {
      return StreakInfo(
        currentStreak: 0,
        bestStreak: 0,
        motivationScore: 0,
        goodDays: [],
        streakStartDate: DateTime.now(),
      );
    }

    final sortedLogs = [...logs]..sort((a, b) => b.date.compareTo(a.date));

    // Find all good days
    final goodDays = sortedLogs
        .where((log) => log.itchIntensity <= goodDayThreshold)
        .map((l) => l.date)
        .toList();

    // Calculate current streak (from most recent)
    int currentStreak = 0;
    DateTime? streakStartDate;

    for (final log in sortedLogs) {
      if (log.itchIntensity <= goodDayThreshold) {
        currentStreak++;
        streakStartDate = log.date;
      } else {
        break; // Streak broken
      }
    }

    // Calculate best streak ever
    int bestStreak = 0;
    int tempStreak = 0;

    for (final log in sortedLogs.reversed) {
      if (log.itchIntensity <= goodDayThreshold) {
        tempStreak++;
        bestStreak = max(bestStreak, tempStreak);
      } else {
        tempStreak = 0;
      }
    }

    // Calculate motivation score (0-100)
    final goodDayPercentage = (goodDays.length / sortedLogs.length) * 100;
    final motivationScore = min(100.0, goodDayPercentage * 1.2);

    return StreakInfo(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      motivationScore: motivationScore.clamp(0, 100).toDouble(),
      goodDays: goodDays,
      streakStartDate: streakStartDate ?? DateTime.now(),
    );
  }

  /// 6. RED FLAG DETECTION: Identify emergency symptoms requiring medical attention
  static List<RedFlag> detectRedFlags(
    List<DailyLog> logs,
    ClinicalDisorder disorder,
  ) {
    final detectedFlags = <RedFlag>[];

    if (logs.isEmpty) return detectedFlags;

    final sorted = _sortedByDateAscending(logs);
    final lastLog = sorted.last;

    // Check against disorder's red flags
    for (final registryFlag in disorder.redFlags) {
      // Match based on symptom severity
      bool matches = false;

      // Emergency: extreme itch + sleep disruption
      if (registryFlag.urgency == 'emergency') {
        matches = lastLog.itchIntensity >= 9 &&
            (lastLog.sleepDisruption || lastLog.mood <= 1);
      }
      // Urgent: high itch + sleep disruption
      else if (registryFlag.urgency == 'urgent') {
        matches = lastLog.itchIntensity >= 8 &&
            (lastLog.sleepDisruption || lastLog.mood <= 2);
      }
      // Soon: moderate itch + some concern
      else if (registryFlag.urgency == 'soon') {
        matches = lastLog.itchIntensity >= 6 && lastLog.sleepQuality <= 2;
      }

      if (matches) {
        detectedFlags.add(registryFlag);
      }
    }

    return detectedFlags;
  }

  /// 7. FLARE RISK PREDICTION: 7-day forward prediction
  static FlareRiskPrediction predictFlareRisk(
    List<DailyLog> logs,
    List<EvidencedTrigger> detectedTriggers,
  ) {
    if (logs.length < _minLogsForRiskPrediction) {
      return FlareRiskPrediction(
        riskPercentage: 50.0,
        daysAhead: 7,
        topTriggers: [],
        confidenceLevel: 'Low',
        calculatedAt: DateTime.now(),
      );
    }

    final sorted = _sortedByDateAscending(logs);

    // Base risk from recent itch levels
    final recentLogs =
        sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
    final recentAvgItch =
        recentLogs.map((l) => l.itchIntensity).reduce((a, b) => a + b) /
            recentLogs.length;

    var baseRisk = (recentAvgItch / 10.0) * 100.0;

    // Adjust based on current state
    final lastLog = sorted.last;
    if (lastLog.stressLevel >= 7) baseRisk += 15.0;
    if (lastLog.sleepQuality <= 2) baseRisk += 15.0;
    if (lastLog.sleepDisruption) baseRisk += 10.0;
    if (lastLog.mood <= 2) baseRisk += 10.0;

    // Get top 3 triggers by confidence
    final topTriggers = detectedTriggers.take(3).map((t) => t.name).toList();

    // Determine confidence level
    String confidenceLevel = 'Medium';
    if (sorted.length >= 21) confidenceLevel = 'High';
    if (sorted.length < 10) confidenceLevel = 'Low';

    return FlareRiskPrediction(
      riskPercentage: min(100.0, baseRisk),
      daysAhead: 7,
      topTriggers: topTriggers,
      confidenceLevel: confidenceLevel,
      calculatedAt: DateTime.now(),
    );
  }

  /// 8. COMPREHENSIVE INSIGHTS GENERATION
  /// Main entry point - orchestrates all analysis and returns complete summary
  ///
  /// [todayWearable] - optional today's wearable aggregate for risk modifier
  static Future<DailyInsightSummary> generateDailyInsights(
    List<DailyLog> logs,
    String condition,
    ClinicalDisorder disorder, {
    DailyWearableAggregate? todayWearable,
  }) async {
    // Clinical disclaimer always present
    final disclaimer =
        'WARNING: These insights are based on statistical analysis of YOUR data only. They are NOT medical diagnoses or treatment recommendations. Always consult a dermatologist before making changes.';

    final sorted = _sortedByDateAscending(logs);

    // Run all analyses
    final triggers = identifyTriggers(sorted, condition, disorder);
    final patterns = detectPatterns(sorted);
    final streaks = calculateStreaks(sorted);
    final redFlags = detectRedFlags(sorted, disorder);
    final flareRisk = predictFlareRisk(sorted, triggers);

    // WEARABLE ADDITION: compute wearable snapshot and pass modifier to risk calc
    WearableSnapshot? wearableSnapshot;
    if (todayWearable != null) {
      final mod = WearableRiskModifier.fromAggregate(todayWearable);
      wearableSnapshot = WearableSnapshot(
        hrv: todayWearable.hrvNightly,
        sleepMinutes: todayWearable.totalSleepMinutes,
        steps: todayWearable.steps,
        wearableRiskModifier: mod?.modifier ?? 0,
      );
    }

    // Calculate overall health score (0-100)
    int healthScore = 100;
    if (sorted.isNotEmpty) {
      final lastLog = sorted.last;
      healthScore -= (lastLog.itchIntensity * 5); // Itch is major factor
      healthScore -= ((5 - lastLog.mood) * 8); // Mood matters
      healthScore -= ((5 - lastLog.sleepQuality) * 4); // Sleep matters
      if (lastLog.sleepDisruption) healthScore -= 10;
      healthScore = healthScore.clamp(0, 100);
    }

    final density = LogDensityConfidence.forLast7Days(sorted);

    // Build comprehensive summary
    return DailyInsightSummary(
      date: DateTime.now(),
      condition: condition,
      healthScore: healthScore,
      disclaimer: disclaimer,
      detectedTriggers: triggers,
      patterns: patterns,
      streakInfo: streaks,
      redFlags: redFlags,
      flareRiskPrediction: flareRisk,
      dataPoints: sorted.length,
      analysisConfidence: sorted.length >= 21
          ? 'High'
          : sorted.length >= 14
              ? 'Moderate'
              : 'Low',
      loggedDaysLast7: density.loggedDays,
      logWindowDays: density.windowDays,
      logDensityLabel: density.label,
      wearableSnapshot: wearableSnapshot,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Oldest-first copy. Callers (UI lists, DailyLogService) often pass
  /// newest-first; windowing and `.last` are only valid after this sort.
  static List<DailyLog> _sortedByDateAscending(List<DailyLog> logs) {
    return List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Convert day number (1-7, Monday=1) to readable day name
  static String _getDayName(int dayOfWeek) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[(dayOfWeek - 1) % 7];
  }

  /// Two-tailed standard-normal quantile Φ^{-1}(1 − 0.05/(2K)).
  /// Values from common z-tables (NIST / most intro stats texts).
  static double _bonferroniZCrit(int lagCount) {
    const table = <int, double>{
      1: 1.960,
      2: 2.241,
      3: 2.394,
      4: 2.498,
      5: 2.576,
      6: 2.638,
      7: 2.690,
      8: 2.734,
    };
    if (lagCount <= 1) return table[1]!;
    if (lagCount >= 8) return table[8]!;
    return table[lagCount]!;
  }

  static double _tanh(double x) {
    final e2x = exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }

  /// Map a registry trigger name to a daily series aligned with [logs], or
  /// null if there is no meaningful DailyLog signal (caller must skip).
  static List<num>? metricSeriesForTrigger(
      String triggerName, List<DailyLog> logs) {
    return metricMappingForTrigger(triggerName, logs)?.series;
  }

  /// Same mapping as [metricSeriesForTrigger], plus an optional [coverageNote]
  /// when a future mapping covers only part of the registry display name.
  /// Currently populated mappings (stress, sleep, mood, alcohol, smoking) are
  /// full coverage, so [TriggerMetricMapping.coverageNote] is left null.
  static TriggerMetricMapping? metricMappingForTrigger(
    String triggerName,
    List<DailyLog> logs,
  ) {
    final name = triggerName.toLowerCase();

    final isStress = name.contains('stress') || name.contains('psychological');
    final isSleep = name.contains('sleep') || name.contains('deprivation');

    // Eczema: 'Stress & Sleep Deprivation' — both are daily 1–N scales.
    if (isStress && isSleep) {
      return TriggerMetricMapping([
        for (final l in logs)
          ((l.stressLevel / 10.0) + ((5 - l.sleepQuality) / 4.0)) / 2.0,
      ]);
    }

    // Psoriasis: 'Psychological Stress'
    if (isStress) {
      return TriggerMetricMapping(
        [for (final l in logs) l.stressLevel.toDouble()],
      );
    }

    if (isSleep) {
      return TriggerMetricMapping(
        [for (final l in logs) (5 - l.sleepQuality).toDouble()],
      );
    }

    if (name.contains('mood') || name.contains('depression')) {
      return TriggerMetricMapping(
        [for (final l in logs) (5 - l.mood).toDouble()],
      );
    }

    // Psoriasis 'Alcohol Consumption' — patients can tag diet.alcohol.
    if (name.contains('alcohol')) {
      return TriggerMetricMapping([
        for (final l in logs)
          _logHasCanonicalTrigger(l, 'diet', 'alcohol') ? 1.0 : 0.0,
      ]);
    }

    // Psoriasis 'Smoking' — no taxonomy id; presence from tagged trigger text.
    if (name.contains('smoking') ||
        name.contains('cigarette') ||
        name.contains('tobacco')) {
      return TriggerMetricMapping(
        [for (final l in logs) _logHasSmokingTag(l) ? 1.0 : 0.0],
      );
    }

    // Remaining names have no complete daily-varying DailyLog signal:
    // - Cold Weather & Low Humidity / Temperature Drops: no thermometer;
    //   self-tagged environment.cold would overclaim the registry name
    // - Food Allergen Exposure (Milk, Nuts, Eggs): taxonomy has dairy only
    // - Environmental Allergens (Dust Mites, Pollen, Pet Dander): pollen only
    // - Bacterial Infection (Streptococcal / Staph): no infection observation
    // - Skin Trauma (Koebner): affectedAreas is lesion location, not trauma
    // - Obesity (BMI >30): not a daily-varying metric
    // - Medications (Beta-blockers, NSAIDs, Lithium): treatment notes are
    //   skin-therapy adherence, not trigger-drug exposure
    // - High Humidity + Sweating: no humidity/sweat field (heat ≠ humidity)
    // - Harsh Soaps, Detergents, Fragrances: no product/irritant field
    // - Dry Air & Low Humidity: no humidity field
    // - Itch-Scratch Cycle: tautological with itchIntensity (the outcome)
    return null;
  }

  static bool _logHasCanonicalTrigger(
    DailyLog log,
    String topLevel,
    String subLevel,
  ) {
    final full = '$topLevel.$subLevel';
    final structured = log.structuredTriggerIds ?? const [];
    if (structured.contains(full)) return true;
    return normalizeTriggers(log.triggers).any(
      (n) => n.id.topLevel == topLevel && n.id.subLevel == subLevel,
    );
  }

  static bool _logHasSmokingTag(DailyLog log) {
    const keywords = ['smoking', 'cigarette', 'tobacco'];
    for (final raw in [...?log.structuredTriggerIds, ...?log.triggers]) {
      final t = raw.toLowerCase();
      if (keywords.any(t.contains)) return true;
    }
    return false;
  }
}

/// Daily series used to correlate a registry trigger, plus an optional
/// coverage caveat when the series is narrower than the trigger's display name.
class TriggerMetricMapping {
  final List<num> series;
  final String? coverageNote;

  const TriggerMetricMapping(this.series, {this.coverageNote});
}

/// Correlate normalized trigger categories with validated PRO scores (POEM/DLQI).
///
/// - Buckets data by week (Sunday–Saturday, matching WeeklySelfEfficacyPulse).
/// - For each week with at least one PRO, computes:
///   - trigger frequency per top-level category (number of days with that trigger)
///   - representative PRO score for the week (latest assessment)
/// - Then calculates Pearson correlation between weekly trigger frequency
///   and weekly PRO scores, returning categories with meaningful correlations.
class TriggerProCorrelationEngine {
  static DateTime _weekStart(DateTime d) {
    // Align with WeeklySelfEfficacyPulse.getWeekStart
    final weekday = d.weekday; // 1=Mon, 7=Sun
    final daysFromSunday = weekday == 7 ? 0 : weekday;
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: daysFromSunday));
  }

  static List<TriggerProCorrelation> correlate(
    List<DailyLog> logs,
    List<ProAssessment> pros,
  ) {
    if (logs.isEmpty || pros.isEmpty) return const [];

    // 1. Bucket logs by week and accumulate trigger presence
    final Map<DateTime, Map<String, Set<String>>> weekToCategoryDays = {};
    for (final log in logs) {
      final week = _weekStart(log.date);
      final topLevels = topLevelTriggersForLog(log);
      if (topLevels.isEmpty) continue;

      final dayKey = '${log.date.year}-${log.date.month}-${log.date.day}';
      final mapForWeek =
          weekToCategoryDays.putIfAbsent(week, () => <String, Set<String>>{});
      for (final cat in topLevels) {
        final setForCat = mapForWeek.putIfAbsent(cat, () => <String>{});
        setForCat.add(dayKey);
      }
    }

    if (weekToCategoryDays.isEmpty) return const [];

    // 2. Bucket PRO assessments by week (use latest per week)
    final Map<DateTime, ProAssessment> weekToPro = {};
    for (final a in pros) {
      final week = _weekStart(a.date);
      final existing = weekToPro[week];
      if (existing == null || a.date.isAfter(existing.date)) {
        weekToPro[week] = a;
      }
    }

    if (weekToPro.isEmpty) return const [];

    // 3. For weeks that have both triggers and PRO, build vectors
    final weeks = weekToPro.keys.toList()..sort((a, b) => a.compareTo(b));
    if (weeks.length < 4) return const []; // too little data

    // Collect all categories
    final categories = <String>{};
    for (var m in weekToCategoryDays.values) {
      categories.addAll(m.keys);
    }

    final results = <TriggerProCorrelation>[];

    for (final cat in categories) {
      final xs = <num>[];
      final ys = <num>[];

      for (final week in weeks) {
        final pro = weekToPro[week];
        if (pro == null) continue;

        final catDays = weekToCategoryDays[week]?[cat]?.length ?? 0;
        // Only use weeks where we have at least one log (even if trigger not present)
        final anyLogsInWeek = weekToCategoryDays.containsKey(week);
        if (!anyLogsInWeek) continue;

        xs.add(catDays);
        ys.add(pro.totalScore);
      }

      // Require a reasonable amount of longitudinal data.
      if (xs.length < 8) continue;

      // Use Spearman (rank) correlation for sparse, ordinal-like data.
      final r = InsightEngine.calculateSpearman(xs, ys);
      if (r.abs() < 0.4) continue; // require at least moderate relationship

      // Compute avg PRO when trigger exposure is "high" vs "low" based on median
      final sorted = [...xs]..sort();
      final median = sorted[sorted.length ~/ 2];
      double sumHigh = 0;
      double sumLow = 0;
      int countHigh = 0;
      int countLow = 0;

      for (var i = 0; i < xs.length; i++) {
        if (xs[i] > median) {
          sumHigh += ys[i];
          countHigh++;
        } else {
          sumLow += ys[i];
          countLow++;
        }
      }

      if (countHigh == 0 || countLow == 0) continue;

      final avgHigh = sumHigh / countHigh;
      final avgLow = sumLow / countLow;

      results.add(
        TriggerProCorrelation(
          category: cat,
          r: r,
          weeks: xs.length,
          avgProHigh: avgHigh,
          avgProLow: avgLow,
        ),
      );
    }

    results.sort((a, b) => b.r.abs().compareTo(a.r.abs()));
    return results;
  }

  // WEARABLE ADDITION: correlate wearable metrics with PRO scores
  static List<TriggerProCorrelation> correlateWearableWithPro(
    List<DailyWearableAggregate> aggregates,
    List<ProAssessment> pros,
  ) {
    if (aggregates.isEmpty || pros.isEmpty) return const [];

    DateTime parseDate(String s) {
      final parts = s.split('-');
      if (parts.length != 3) return DateTime.now();
      return DateTime(
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 1,
        int.tryParse(parts[2]) ?? 1,
      );
    }

    final weekToHrv = <DateTime, List<double>>{};
    final weekToSleep = <DateTime, List<int>>{};
    final weekToSteps = <DateTime, List<int>>{};

    for (final a in aggregates) {
      final week = _weekStart(parseDate(a.date));
      if (a.hrvNightly != null) {
        weekToHrv.putIfAbsent(week, () => []).add(a.hrvNightly!);
      }
      if (a.totalSleepMinutes != null) {
        weekToSleep.putIfAbsent(week, () => []).add(a.totalSleepMinutes!);
      }
      if (a.steps != null) {
        weekToSteps.putIfAbsent(week, () => []).add(a.steps!);
      }
    }

    final weekToPro = <DateTime, ProAssessment>{};
    for (final p in pros) {
      final week = _weekStart(p.date);
      final existing = weekToPro[week];
      if (existing == null || p.date.isAfter(existing.date)) {
        weekToPro[week] = p;
      }
    }

    if (weekToPro.isEmpty) return const [];

    final weeks = weekToPro.keys.toList()..sort((a, b) => a.compareTo(b));
    if (weeks.length < 8) return const [];

    final results = <TriggerProCorrelation>[];

    void addMetric(
      String category,
      Map<DateTime, List<num>> weekToValues,
      num Function(List<num>) reduce,
    ) {
      final xs = <num>[];
      final ys = <num>[];
      for (final week in weeks) {
        final pro = weekToPro[week];
        if (pro == null) continue;
        final vals = weekToValues[week];
        if (vals == null || vals.isEmpty) continue;
        xs.add(reduce(vals));
        ys.add(pro.totalScore);
      }
      if (xs.length < 8) return;
      final r = InsightEngine.calculateSpearman(xs, ys);
      if (r.abs() < 0.4) return;
      final sorted = [...xs]..sort((a, b) => a.compareTo(b));
      final median = sorted[sorted.length ~/ 2];
      double sumHigh = 0, sumLow = 0;
      int countHigh = 0, countLow = 0;
      for (var i = 0; i < xs.length; i++) {
        if (xs[i] > median) {
          sumHigh += ys[i];
          countHigh++;
        } else {
          sumLow += ys[i];
          countLow++;
        }
      }
      if (countHigh == 0 || countLow == 0) return;
      results.add(
        TriggerProCorrelation(
          category: category,
          r: r,
          weeks: xs.length,
          avgProHigh: sumHigh / countHigh,
          avgProLow: sumLow / countLow,
        ),
      );
    }

    addMetric(
      'wearable.hrv',
      weekToHrv.map((k, v) => MapEntry(k, v.map((e) => e as num).toList())),
      (l) => l.reduce((a, b) => a + b) / l.length,
    );
    addMetric(
      'wearable.sleep',
      weekToSleep.map((k, v) => MapEntry(k, v.map((e) => e as num).toList())),
      (l) => l.reduce((a, b) => a + b) / l.length,
    );
    addMetric(
      'wearable.activity',
      weekToSteps.map((k, v) => MapEntry(k, v.map((e) => e as num).toList())),
      (l) => l.reduce((a, b) => a + b) / l.length,
    );

    results.sort((a, b) => b.r.abs().compareTo(a.r.abs()));
    return results;
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// DATA MODELS - Core insight output structures
/// ═══════════════════════════════════════════════════════════════════════

/// Pattern detected in user's data
class PatternInsight {
  final String pattern;
  final String description;
  final double confidence; // 0-1 scale
  final int occurrences; // How many times pattern occurred
  final String predictability; // Low, Medium, High

  PatternInsight({
    required this.pattern,
    required this.description,
    required this.confidence,
    required this.occurrences,
    required this.predictability,
  });

  @override
  String toString() =>
      '$pattern (confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}

/// Streak information for motivation tracking
class StreakInfo {
  final int currentStreak; // Current consecutive good days
  final int bestStreak; // Best streak ever achieved
  final double motivationScore; // 0-100 based on good day %
  final List<DateTime> goodDays; // List of all good days
  final DateTime streakStartDate; // When current streak started

  StreakInfo({
    required this.currentStreak,
    required this.bestStreak,
    required this.motivationScore,
    required this.goodDays,
    required this.streakStartDate,
  });

  String get motivationLabel {
    if (motivationScore >= 80) return 'Excellent 🎉';
    if (motivationScore >= 60) return 'Good 👍';
    if (motivationScore >= 40) return 'Moderate ⚖️';
    return 'Low 😟';
  }

  @override
  String toString() => '$currentStreak day streak (best: $bestStreak days)';
}

/// 7-day flare risk prediction
class FlareRiskPrediction {
  final double riskPercentage; // 0-100
  final int daysAhead; // Always 7
  final List<String> topTriggers; // Top 3 detected triggers
  final String confidenceLevel; // Low, Medium, High
  final DateTime calculatedAt;

  FlareRiskPrediction({
    required this.riskPercentage,
    required this.daysAhead,
    required this.topTriggers,
    required this.confidenceLevel,
    required this.calculatedAt,
  });

  String get riskLabel {
    if (riskPercentage >= 70) return '🚨 High Risk';
    if (riskPercentage >= 40) return '⚠️ Moderate Risk';
    return '✅ Low Risk';
  }

  @override
  String toString() =>
      '${riskPercentage.toStringAsFixed(0)}% risk ($confidenceLevel confidence)';
}

/// Wearable snapshot for today (HRV, sleep, steps, risk modifier).
class WearableSnapshot {
  final double? hrv;
  final int? sleepMinutes;
  final int? steps;
  final int wearableRiskModifier;

  const WearableSnapshot({
    this.hrv,
    this.sleepMinutes,
    this.steps,
    required this.wearableRiskModifier,
  });
}

/// Complete daily insight summary (main output)
class DailyInsightSummary {
  final DateTime date;
  final String condition;
  final int healthScore; // 0-100
  final String disclaimer;
  final List<EvidencedTrigger> detectedTriggers;
  final List<PatternInsight> patterns;
  final StreakInfo streakInfo;
  final List<RedFlag> redFlags;
  final FlareRiskPrediction flareRiskPrediction;
  final int dataPoints; // Number of logs analyzed
  final String analysisConfidence; // Low, Moderate, High
  final WearableSnapshot? wearableSnapshot;

  /// Distinct log days in the last 7-day window, for confidence indicators.
  final int loggedDaysLast7;
  final int logWindowDays;
  final String logDensityLabel; // 'High' | 'Medium' | 'Low'

  DailyInsightSummary({
    required this.date,
    required this.condition,
    required this.healthScore,
    required this.disclaimer,
    required this.detectedTriggers,
    required this.patterns,
    required this.streakInfo,
    required this.redFlags,
    required this.flareRiskPrediction,
    required this.dataPoints,
    required this.analysisConfidence,
    required this.loggedDaysLast7,
    required this.logWindowDays,
    required this.logDensityLabel,
    this.wearableSnapshot,
  });

  String get healthLabel {
    if (healthScore >= 80) return 'Excellent';
    if (healthScore >= 60) return 'Good';
    if (healthScore >= 40) return 'Fair';
    return 'Needs Attention';
  }

  /// Quick summary for UI display
  String getSummary() {
    final triggerSummary = detectedTriggers.isEmpty
        ? 'No clear triggers detected'
        : 'Top trigger: ${detectedTriggers.first.name} (${detectedTriggers.first.confidence.toStringAsFixed(0)}% confidence)';
    final densityPart = '$loggedDaysLast7/$logWindowDays days logged this week';

    return '$healthLabel | Health: $healthScore/100\n'
        '$triggerSummary\n'
        '${flareRiskPrediction.riskLabel}\n'
        '$densityPart';
  }

  @override
  String toString() =>
      'InsightSummary($condition, $healthLabel, ${redFlags.length} red flags)';
}
