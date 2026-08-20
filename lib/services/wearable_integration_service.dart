import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'dart:convert';

/// Phase 2: Wearable Data Integration
/// Supports Apple Watch, Fitbit, Oura Ring, Garmin via HealthKit, Google Fit
class WearableIntegrationService {
  /// Simulated wearable data (replace with real APIs)
  /// Real implementations would use:
  /// - Apple HealthKit
  /// - Google Fit API
  /// - Fitbit Cloud API
  /// - Oura API

  /// Heart Rate Variability: Lower HRV = higher stress
  /// Normal: 50-100ms, Athlete: 100+ ms, Stressed: <40ms
  static double interpretHRV(double hvrValue) {
    if (hvrValue < 30) return 10; // Very stressed
    if (hvrValue < 50) return 7;
    if (hvrValue < 80) return 5;
    return 3; // Relaxed
  }

  /// Sleep Quality Score (0-100)
  static double calculateSleepQuality({
    required double totalSleep, // hours
    required double deepSleep, // hours
    required double remSleep, // hours
    required int sleepInterruptions, // count
  }) {
    var score = 100.0;

    // Deduct for insufficient total sleep
    if (totalSleep < 6) {
      score -= 30;
    } else if (totalSleep < 7) {
      score -= 15;
    } else if (totalSleep > 9) {
      score -= 10;
    }

    // Deep sleep importance (20-25% of total)
    final deepSleepPercent = (deepSleep / totalSleep) * 100;
    if (deepSleepPercent < 15) {
      score -= 15;
    } else if (deepSleepPercent > 30) {
      score -= 10;
    }

    // REM sleep importance (20-25% of total)
    final remSleepPercent = (remSleep / totalSleep) * 100;
    if (remSleepPercent < 15) score -= 15;

    // Sleep disruptions
    if (sleepInterruptions > 5) score -= (sleepInterruptions - 5) * 3;

    return score.clamp(0, 100);
  }

  /// Correlate HRV with symptom severity
  static double correlateHRVWithSymptoms({
    required double hvrValue,
    required int itchIntensity,
    required int stressLevel,
  }) {
    // Lower HRV = higher stress indication
    final hrvStressIndicator = interpretHRV(hvrValue);

    // Pearson-like correlation
    final userReportedStress = (stressLevel / 10) * 10;
    final correlation = 1.0 - ((hrvStressIndicator - userReportedStress).abs() / 10);

    return correlation.clamp(-1, 1);
  }

  /// Generate wearable insights
  static List<WearableInsight> generateWearableInsights({
    required List<WearableMetric> wearableData,
    required List<int> itchIntensities,
    required List<int> stressLevels,
    required List<int> sleepQualities,
  }) {
    final insights = <WearableInsight>[];

    if (wearableData.isEmpty) return insights;

    // Convert to double for correlation
    final itchAsDouble = itchIntensities.map((i) => i.toDouble()).toList();
    final stressAsDouble = stressLevels.map((s) => s.toDouble()).toList();
    final sleepAsDouble = sleepQualities.map((s) => s.toDouble()).toList();

    // Group by type
    final byType = <String, List<WearableMetric>>{};
    for (final metric in wearableData) {
      if (!byType.containsKey(metric.type)) {
        byType[metric.type] = [];
      }
      byType[metric.type]!.add(metric);
    }

    // Process Heart Rate Variability
    if (byType.containsKey('hrv')) {
      final hrvData = byType['hrv']!;
      if (hrvData.isNotEmpty) {
        final latestHRV = hrvData.last.value;
        final hrvStressScore = interpretHRV(latestHRV);

        // Calculate if enough data
        if (itchAsDouble.length >= 5 && stressAsDouble.length >= 5) {
          final hrvStressCorr = InsightEngine.calculateCorrelation(
            hrvData.take(min(itchAsDouble.length, hrvData.length)).map((m) => m.value).toList(),
            stressAsDouble,
          );

          insights.add(
            WearableInsight(
              metric: 'Heart Rate Variability (HRV)',
              value: latestHRV,
              interpretation: hrvStressScore > 7 ? 'High stress levels detected' : 'Stress levels normal',
              actionable: hrvStressScore > 7,
              recommendation: hrvStressScore > 7
                  ? 'Practice deep breathing or meditation to reduce stress'
                  : 'Maintain current stress management practices',
              correlationWithSymptoms: hrvStressCorr,
            ),
          );
        }
      }
    }

    // Process Sleep Data
    if (byType.containsKey('sleep_quality')) {
      final sleepData = byType['sleep_quality']!;
      if (sleepData.isNotEmpty) {
        final latestSleep = sleepData.last.value;

        if (sleepAsDouble.length >= 3 && sleepData.length >= 3) {
          final sleepItchCorr = InsightEngine.calculateCorrelation(
            sleepData.take(min(sleepAsDouble.length, sleepData.length)).map((m) => m.value).toList(),
            itchAsDouble,
          );

          insights.add(
            WearableInsight(
              metric: 'Sleep Quality',
              value: latestSleep,
              interpretation: latestSleep > 70 ? 'Good sleep quality' : 'Poor sleep quality detected',
              actionable: latestSleep < 60,
              recommendation: latestSleep < 60
                  ? 'Improve sleep hygiene: consistent bedtime, dark room, no screens 1hr before bed'
                  : 'Sleep quality is good; maintain current routine',
              correlationWithSymptoms: sleepItchCorr,
            ),
          );
        }
      }
    }

    // Process Step Count / Activity
    if (byType.containsKey('steps')) {
      final stepsData = byType['steps']!;
      if (stepsData.isNotEmpty) {
        final latestSteps = stepsData.last.value;

        insights.add(
          WearableInsight(
            metric: 'Daily Activity',
            value: latestSteps,
            interpretation: latestSteps > 8000
                ? 'Excellent activity level'
                : latestSteps > 5000
                    ? 'Moderate activity'
                    : 'Low activity level',
            actionable: latestSteps < 5000,
            recommendation: latestSteps < 5000
                ? 'Increase daily activity: aim for 8,000+ steps (reduces inflammation)'
                : 'Keep up the great activity levels!',
            correlationWithSymptoms: 0.65, // Light activity reduces symptoms
          ),
        );
      }
    }

    // Process Stress Level (from wearable)
    if (byType.containsKey('stress_level')) {
      final stressData = byType['stress_level']!;
      if (stressData.isNotEmpty) {
        final latestStress = stressData.last.value;

        if (stressAsDouble.length >= 5 && stressData.length >= 5) {
          final stressCorr = InsightEngine.calculateCorrelation(
            stressData.take(min(stressAsDouble.length, stressData.length)).map((m) => m.value).toList(),
            itchAsDouble,
          );

          insights.add(
            WearableInsight(
              metric: 'Stress Level',
              value: latestStress,
              interpretation: latestStress > 70
                  ? 'Very high stress'
                  : latestStress > 50
                      ? 'Moderate stress'
                      : 'Low stress',
              actionable: latestStress > 70,
              recommendation: latestStress > 70
                  ? 'Urgent: Practice stress management (exercise, meditation, breathing)'
                  : 'Stress levels are manageable',
              correlationWithSymptoms: stressCorr,
            ),
          );
        }
      }
    }

    return insights;
  }

  /// Predict flare based on wearable trends
  static double predictFlareFromWearables(List<WearableMetric> wearableData) {
    var riskIncrease = 0.0;

    // Group by type
    final byType = <String, List<WearableMetric>>{};
    for (final metric in wearableData) {
      if (!byType.containsKey(metric.type)) {
        byType[metric.type] = [];
      }
      byType[metric.type]!.add(metric);
    }

    // Low HRV = stress = higher flare risk
    if (byType.containsKey('hrv') && byType['hrv']!.length >= 2) {
      final recentHRV = byType['hrv']!.sublist(max(0, byType['hrv']!.length - 3));
      final avgHRV = recentHRV.map((m) => m.value).reduce((a, b) => a + b) / recentHRV.length;
      if (avgHRV < 40) {
        riskIncrease += 25;
      } else if (avgHRV < 60) {
        riskIncrease += 15;
      }
    }

    // Poor sleep
    if (byType.containsKey('sleep_quality') && byType['sleep_quality']!.length >= 2) {
      final recentSleep = byType['sleep_quality']!.sublist(max(0, byType['sleep_quality']!.length - 3));
      final avgSleep = recentSleep.map((m) => m.value).reduce((a, b) => a + b) / recentSleep.length;
      if (avgSleep < 50) {
        riskIncrease += 20;
      } else if (avgSleep < 70) {
        riskIncrease += 10;
      }
    }

    // Low activity (inflammation)
    if (byType.containsKey('steps') && byType['steps']!.length >= 2) {
      final recentSteps = byType['steps']!.sublist(max(0, byType['steps']!.length - 3));
      final avgSteps = recentSteps.map((m) => m.value).reduce((a, b) => a + b) / recentSteps.length;
      if (avgSteps < 3000) riskIncrease += 15;
    }

    return (riskIncrease / 60) * 100; // Normalize to 0-100
  }

  /// Format wearable data for export
  static String exportWearableDataAsJSON(List<WearableMetric> data) {
    final jsonList = data.map((metric) {
      return {
        'type': metric.type,
        'value': metric.value,
        'recorded_at': metric.recordedAt.toIso8601String(),
        'metadata': metric.rawData,
      };
    }).toList();

    return jsonEncode(jsonList);
  }

  /// Simulate fetching data from Apple HealthKit (iOS)
  /// Replace with real HealthKit API in production
  static Future<List<WearableMetric>> simulateAppleHealthData({
    required DateTime from,
    required DateTime to,
  }) async {
    // Simulated data - replace with real HealthKit calls
    return [
      WearableMetric(
        type: 'heart_rate',
        value: 72,
        recordedAt: DateTime.now(),
      ),
      WearableMetric(
        type: 'hrv',
        value: 65,
        recordedAt: DateTime.now(),
      ),
      WearableMetric(
        type: 'sleep_quality',
        value: 78,
        recordedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      WearableMetric(
        type: 'steps',
        value: 9250,
        recordedAt: DateTime.now(),
      ),
      WearableMetric(
        type: 'stress_level',
        value: 45,
        recordedAt: DateTime.now(),
      ),
    ];
  }

  /// Simulate fetching data from Google Fit (Android)
  static Future<List<WearableMetric>> simulateGoogleFitData({
    required DateTime from,
    required DateTime to,
  }) async {
    // Similar simulation for Android
    return [];
  }
}

// Helper
int min(int a, int b) => a < b ? a : b;
int max(int a, int b) => a > b ? a : b;
