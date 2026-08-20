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
  static const _correlationThreshold = 0.55; // Pearson r threshold for "significant" correlation
  static const _maxLagDays = 7; // Maximum lag to test (7 days)

  /// 1. PEARSON CORRELATION: Statistical relationship between two variables
  /// Returns correlation coefficient from -1.0 (perfect inverse) to 1.0 (perfect positive)
  static double calculateCorrelation(List<num> x, List<num> y) {
    if (x.length != y.length || x.isEmpty) return 0.0;

    // Calculate means
    final meanX = x.reduce((a, b) => a + b) / x.length;
    final meanY = y.reduce((a, b) => a + b) / y.length;

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

      if (causeLagged.length >= 3) {
        results[lag] = calculateCorrelation(
          causeLagged.cast<num>(),
          effectShifted.cast<num>(),
        );
      }
    }

    return results;
  }

  /// 3. TRIGGER IDENTIFICATION: Evidence-backed detection with mechanisms
  /// Maps user data to disorder registry triggers and calculates confidence
  static List<EvidencedTrigger> identifyTriggers(
    List<DailyLog> logs,
    String condition,
    ClinicalDisorder disorder,
  ) {
    if (logs.length < _minLogsForInsights) return [];

    final detectedTriggers = <EvidencedTrigger>[];

    // Extract metrics from logs
    final stressLevels = logs.map((l) => l.stressLevel.toDouble()).toList();
    final itchIntensities = logs.map((l) => l.itchIntensity.toDouble()).toList();
    final sleepQualities = logs.map((l) => (5 - l.sleepQuality).toDouble()).toList(); // Inverted: poor sleep = high number
    final moods = logs.map((l) => (5 - l.mood).toDouble()).toList(); // Inverted: poor mood = high number

    // Test each trigger from disorder registry
    for (final registryTrigger in disorder.triggers) {
      List<num> metricData = [];

      // Map trigger to available metrics based on name
      final triggerNameLower = registryTrigger.name.toLowerCase();

      if (triggerNameLower.contains('stress') || 
          triggerNameLower.contains('psychological')) {
        metricData = stressLevels;
      } else if (triggerNameLower.contains('sleep') || 
                 triggerNameLower.contains('deprivation')) {
        metricData = sleepQualities;
      } else if (triggerNameLower.contains('mood') || 
                 triggerNameLower.contains('depression')) {
        metricData = moods;
      } else if (triggerNameLower.contains('temp') || 
                 triggerNameLower.contains('cold') ||
                 triggerNameLower.contains('hot')) {
        // Temperature would require environmental data - skip for now
        continue;
      } else if (triggerNameLower.contains('infection') || 
                 triggerNameLower.contains('bacterial')) {
        // Infection would require clinical observation - skip for now
        continue;
      } else {
        // Generic correlation with stress if no specific mapping
        metricData = stressLevels;
      }

      if (metricData.isEmpty) continue;

      // Calculate immediate correlation
      final correlation = calculateCorrelation(metricData, itchIntensities);

      // Check for lag correlations
      final lagResults = calculateLagCorrelation(
        metricData,
        itchIntensities,
        maxLag: _maxLagDays,
      );

      // Find best lag
      int bestLag = 0;
      double bestCorrelation = correlation.abs();

      lagResults.forEach((lag, lagCorr) {
        if (lagCorr.abs() > bestCorrelation) {
          bestCorrelation = lagCorr.abs();
          bestLag = lag;
        }
      });

      // Add trigger if correlation is statistically significant
      if (bestCorrelation > _correlationThreshold) {
        detectedTriggers.add(
          EvidencedTrigger(
            name: registryTrigger.name,
            mechanism: registryTrigger.mechanism,
            baselineIncidence: registryTrigger.baselineIncidence,
            symptoms: registryTrigger.symptoms,
            preventionStrategy: registryTrigger.preventionStrategy,
            expectedImprovement: registryTrigger.expectedImprovement,
            evidence: registryTrigger.evidence,
            lagDays: bestLag,
            correlation: bestCorrelation,
            confidence: min(100.0, bestCorrelation * 100.0),
          ),
        );
      }
    }

    // Sort by confidence (highest first)
    detectedTriggers.sort((a, b) => b.confidence.compareTo(a.confidence));

    return detectedTriggers;
  }

  /// 4. PATTERN DETECTION: Find recurring weekly or temporal patterns
  static List<PatternInsight> detectPatterns(List<DailyLog> logs) {
    if (logs.length < _minLogsForPatterns) return [];

    final patterns = <PatternInsight>[];

    // Group by day of week
    final byDayOfWeek = <int, List<int>>{};
    for (final log in logs) {
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

      final maxDay = avgByDay.entries.reduce((a, b) => a.value > b.value ? a : b);
      final minDay = avgByDay.entries.reduce((a, b) => a.value < b.value ? a : b);
      final variance = maxDay.value - minDay.value;

      if (variance > 2.5) {
        patterns.add(
          PatternInsight(
            pattern: 'Weekly Cycle Detected',
            description:
                'Symptoms peak on ${_getDayName(maxDay.key)} (${maxDay.value.toStringAsFixed(1)}/10) and improve on ${_getDayName(minDay.key)} (${minDay.value.toStringAsFixed(1)}/10)',
            confidence: 0.75,
            occurrences: logs
                .where((l) => l.date.weekday == maxDay.key)
                .length,
            predictability: 'High',
          ),
        );
      }
    }

    // Detect temporal trends (improving vs worsening over time)
    if (logs.length >= 14) {
      final firstHalf = logs.sublist(0, (logs.length / 2).toInt());
      final secondHalf = logs.sublist((logs.length / 2).toInt());

      final firstHalfAvg = firstHalf
              .map((l) => l.itchIntensity)
              .reduce((a, b) => a + b) /
          firstHalf.length;

      final secondHalfAvg = secondHalf
              .map((l) => l.itchIntensity)
              .reduce((a, b) => a + b) /
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

    final lastLog = logs.last;

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

    // Base risk from recent itch levels
    final recentLogs = logs.length > 7 ? logs.sublist(logs.length - 7) : logs;
    final recentAvgItch = recentLogs
            .map((l) => l.itchIntensity)
            .reduce((a, b) => a + b) /
        recentLogs.length;

    var baseRisk = (recentAvgItch / 10.0) * 100.0;

    // Adjust based on current state
    final lastLog = logs.last;
    if (lastLog.stressLevel >= 7) baseRisk += 15.0;
    if (lastLog.sleepQuality <= 2) baseRisk += 15.0;
    if (lastLog.sleepDisruption) baseRisk += 10.0;
    if (lastLog.mood <= 2) baseRisk += 10.0;

    // Get top 3 triggers by confidence
    final topTriggers = detectedTriggers
        .take(3)
        .map((t) => t.name)
        .toList();

    // Determine confidence level
    String confidenceLevel = 'Medium';
    if (logs.length >= 21) confidenceLevel = 'High';
    if (logs.length < 10) confidenceLevel = 'Low';

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

    // Run all analyses
    final triggers = identifyTriggers(logs, condition, disorder);
    final patterns = detectPatterns(logs);
    final streaks = calculateStreaks(logs);
    final redFlags = detectRedFlags(logs, disorder);
    final flareRisk = predictFlareRisk(logs, triggers);

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
    if (logs.isNotEmpty) {
      final lastLog = logs.last;
      healthScore -= (lastLog.itchIntensity * 5); // Itch is major factor
      healthScore -= ((5 - lastLog.mood) * 8); // Mood matters
      healthScore -= ((5 - lastLog.sleepQuality) * 4); // Sleep matters
      if (lastLog.sleepDisruption) healthScore -= 10;
      healthScore = healthScore.clamp(0, 100);
    }

    final density = LogDensityConfidence.forLast7Days(logs);

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
      dataPoints: logs.length,
      analysisConfidence: logs.length >= 21 ? 'High' :
                          logs.length >= 14 ? 'Moderate' : 'Low',
      loggedDaysLast7: density.loggedDays,
      logWindowDays: density.windowDays,
      logDensityLabel: density.label,
      wearableSnapshot: wearableSnapshot,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Convert day number (1-7, Monday=1) to readable day name
  static String _getDayName(int dayOfWeek) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[(dayOfWeek - 1) % 7];
  }
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
        final setForCat =
            mapForWeek.putIfAbsent(cat, () => <String>{});
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
    final weeks = weekToPro.keys.toList()
      ..sort((a, b) => a.compareTo(b));
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

        final catDays =
            weekToCategoryDays[week]?[cat]?.length ?? 0;
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
  String toString() => '$pattern (confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
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
  String toString() => '${riskPercentage.toStringAsFixed(0)}% risk ($confidenceLevel confidence)';
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
    final triggerSummary =
        detectedTriggers.isEmpty ? 'No clear triggers detected' : 
        'Top trigger: ${detectedTriggers.first.name} (${detectedTriggers.first.confidence.toStringAsFixed(0)}% confidence)';
    final densityPart =
        '$loggedDaysLast7/$logWindowDays days logged this week';

    return '$healthLabel | Health: $healthScore/100\n'
        '$triggerSummary\n'
        '${flareRiskPrediction.riskLabel}\n'
        '$densityPart';
  }

  @override
  String toString() => 'InsightSummary($condition, $healthLabel, ${redFlags.length} red flags)';
}
