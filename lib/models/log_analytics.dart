import 'package:dhealth/config/risk_score_config.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/personal_weight_profile.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/risk_score_result.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/personal_weight_calculator.dart';
import 'package:dhealth/services/risk_score_calculator.dart';
import 'package:dhealth/models/flare_event.dart';
import 'package:dhealth/models/medication_exception_event.dart';

class LogAnalytics {
  final List<DailyLog> logs;

  LogAnalytics(this.logs);

  static List<FlareEvent> eligibleFlareOutcomes(List<FlareEvent> events) {
    return events.where((e) => e.isOutcomeEligible).toList();
  }

  static List<MedicationExceptionEvent> medicationExceptionsForLastDays(
    List<MedicationExceptionEvent> events,
    int days,
  ) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return events.where((e) => e.occurredAt.isAfter(cutoff)).toList();
  }

  static int countMissedDosesLastDays(
    List<MedicationExceptionEvent> events,
    int days,
  ) {
    return medicationExceptionsForLastDays(events, days)
        .where((e) => e.type == MedicationExceptionType.missedDose)
        .length;
  }

  /// Get logs from last N days
  List<DailyLog> getLogsFromLastDays(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return logs
        .where((log) => log.date.isAfter(cutoffDate))
        .toList();
  }

  /// Get today's log
  DailyLog? getTodayLog() {
    final today = DateTime.now();
    try {
      return logs.firstWhere(
        (log) =>
            log.date.year == today.year &&
            log.date.month == today.month &&
            log.date.day == today.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get today's risk score (legacy single-log formula)
  int getTodayRiskScore() {
    return getTodayLog()?.calculateRiskScore() ?? 0;
  }

  /// Refined explainable risk score with components, trend, triggers, red-flag override.
  /// Uses patient-specific weights (from 90-day correlation) when >= 30 days of data available.
  RiskScoreResult getRefinedRiskScore(
    String condition,
    ClinicalDisorder disorder, {
    Map<String, dynamic>? envData,
    DailyWearableAggregate? todayWearable,
    List<DailyWearableAggregate>? wearableAggregates,
  }) {
    final logs90 = getLogsFromLastDays(90);
    final sorted = List<DailyLog>.from(logs90)
      ..sort((a, b) => a.date.compareTo(b.date));

    final disorderDefaults = condition.toLowerCase() == 'eczema' ||
            condition.toLowerCase() == 'atopic dermatitis' ||
            condition.toLowerCase() == 'ad'
        ? eczemaRiskWeights
        : psoriasisRiskWeights;

    PersonalWeightProfile? personalProfile;
    if (sorted.length >= 30) {
      personalProfile = PersonalWeightCalculator.computePersonalWeightProfile(
        sorted,
        disorderDefaults,
        wearableAggregates: wearableAggregates,
      );
    }

    // WEARABLE ADDITION: pass wearable risk modifier when today's aggregate provided
    final wearableMod = todayWearable != null
        ? WearableRiskModifier.fromAggregate(todayWearable)
        : null;

    List<EvidencedTrigger>? triggers;
    if (sorted.length >= 10) {
      triggers = InsightEngine.identifyTriggers(sorted, condition, disorder);
    }

    return RiskScoreCalculator.calculate(
      logs: sorted,
      condition: condition,
      disorder: disorder,
      envData: envData,
      detectedTriggers: triggers,
      personalProfile: personalProfile,
      wearableRiskModifier: wearableMod,
    );
  }

  /// Get average risk score for last N days
  double getAverageRiskScore(int days) {
    final recentLogs = getLogsFromLastDays(days);
    if (recentLogs.isEmpty) return 0;
    final total = recentLogs.fold<int>(
      0,
      (sum, log) => sum + log.calculateRiskScore(),
    );
    return total / recentLogs.length;
  }

  /// Get highest risk day in last N days
  int getMaxRiskScore(int days) {
    final recentLogs = getLogsFromLastDays(days);
    if (recentLogs.isEmpty) return 0;
    return recentLogs
        .map((log) => log.calculateRiskScore())
        .reduce((a, b) => a > b ? a : b);
  }

  /// Get risk trend (true = improving, false = worsening)
  bool isTrendImproving() {
    final last7 = getLogsFromLastDays(7);
    if (last7.length < 2) return true;

    final firstHalf = (last7.length / 2).ceil();
    final first3Avg = last7
            .sublist(0, firstHalf)
            .fold<int>(0, (sum, log) => sum + log.calculateRiskScore()) /
        firstHalf;

    final last3Avg = last7
            .sublist(firstHalf)
            .fold<int>(0, (sum, log) => sum + log.calculateRiskScore()) /
        (last7.length - firstHalf);

    return last3Avg < first3Avg;
  }

  /// Get daily mood average
  double getAverageMood(int days) {
    final recentLogs = getLogsFromLastDays(days);
    if (recentLogs.isEmpty) return 0;
    final total = recentLogs.fold<int>(0, (sum, log) => sum + log.mood);
    return total / recentLogs.length;
  }

  /// Get daily itch average
  double getAverageItch(int days) {
    final recentLogs = getLogsFromLastDays(days);
    if (recentLogs.isEmpty) return 0;
    final total = recentLogs.fold<int>(0, (sum, log) => sum + log.itchIntensity);
    return total / recentLogs.length;
  }
}
