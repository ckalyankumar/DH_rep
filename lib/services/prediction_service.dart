class PredictionService {
  /// Calculate flare risk based on individual parameters
  double calculateFlareRisk({
    required int itchIntensity,
    required int stressLevel,
    required int sleepQuality,
    required bool sleepDisruption,
    required List<String> affectedAreas,
    required String lesionSeverity,
  }) {
    double riskScore = 0;

    // Stress impact (0-10 scale)
    riskScore += (stressLevel / 10) * 0.3;

    // Sleep impact
    if (sleepDisruption) riskScore += 0.15;
    riskScore += ((5 - sleepQuality) / 5) * 0.2;

    // Symptom impact
    riskScore += (itchIntensity / 10) * 0.2;
    riskScore += affectedAreas.length * 0.05;

    // Lesion severity impact
    if (lesionSeverity == 'severe') {
      riskScore += 0.15;
    } else if (lesionSeverity == 'moderate') {
      riskScore += 0.1;
    } else if (lesionSeverity == 'mild') {
      riskScore += 0.05;
    }

    return (riskScore * 100).clamp(0, 100);
  }

  /// Get risk level based on percentage
  String getRiskLevel(double riskPercentage) {
    if (riskPercentage < 33) return 'low';
    if (riskPercentage < 67) return 'medium';
    return 'high';
  }

  /// Get recommendation priority based on confidence score
  String getRecommendationPriority(double confidence) {
    if (confidence > 0.8) return 'high';
    if (confidence > 0.5) return 'medium';
    return 'low';
  }

  /// Calculate flare risk from a DailyLog
  double calculateFlareRiskFromLog(Map<String, dynamic> logData) {
    return calculateFlareRisk(
      itchIntensity: logData['itchIntensity'] as int? ?? 0,
      stressLevel: logData['stressLevel'] as int? ?? 0,
      sleepQuality: logData['sleepQuality'] as int? ?? 3,
      sleepDisruption: logData['sleepDisruption'] as bool? ?? false,
      affectedAreas: logData['affectedAreas'] as List<String>? ?? [],
      lesionSeverity: logData['lesionSeverity'] as String? ?? 'mild',
    );
  }

  /// Get color code for risk level
  String getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'high':
        return '#E74C3C';
      case 'medium':
        return '#F39C12';
      case 'low':
        return '#27AE60';
      default:
        return '#95A5A6';
    }
  }

  /// Generate weekly forecast based on trend
  List<double> generateWeeklyForecast(List<double> historicalRisks) {
    if (historicalRisks.length < 3) return historicalRisks;

    List<double> forecast = [];
    double trend = (historicalRisks.last - historicalRisks.first) / historicalRisks.length;

    for (int i = 0; i < 7; i++) {
      double predictedRisk = (historicalRisks.last + (trend * (i + 1))).clamp(0, 100);
      forecast.add(predictedRisk);
    }

    return forecast;
  }

  /// Get factors contributing to the risk
  Map<String, double> getContributingFactors({
    required int itchIntensity,
    required int stressLevel,
    required int sleepQuality,
    required bool sleepDisruption,
    required List<String> affectedAreas,
    required String lesionSeverity,
  }) {
    return {
      'stress': (stressLevel / 10) * 0.3,
      'sleep': ((5 - sleepQuality) / 5) * 0.2 + (sleepDisruption ? 0.15 : 0),
      'itch': (itchIntensity / 10) * 0.2,
      'areas': affectedAreas.length * 0.05,
      'severity': _getSeverityFactor(lesionSeverity),
    };
  }

  /// Calculate trend from historical data
  String calculateTrend(List<double> historicalRisks) {
    if (historicalRisks.length < 2) return 'stable';

    double trend = historicalRisks.last - historicalRisks.first;

    if (trend > 10) return 'worsening';
    if (trend < -10) return 'improving';
    return 'stable';
  }

  /// Helper: Get severity factor
  double _getSeverityFactor(String severity) {
    switch (severity) {
      case 'severe':
        return 0.15;
      case 'moderate':
        return 0.1;
      case 'mild':
        return 0.05;
      default:
        return 0;
    }
  }
}
