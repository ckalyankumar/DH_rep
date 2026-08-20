class PredictionFactor {
  final String name;
  final String value;
  final RiskLevel impact;
  
  PredictionFactor({
    required this.name,
    required this.value,
    required this.impact,
  });
}

enum RiskLevel { high, medium, low }

class FlareRiskPrediction {
  final double riskPercentage;
  final int daysUntilPeakRisk;
  final double confidenceScore;
  final List<PredictionFactor> contributingFactors;
  final List<int> sevenDayForecast; // Risk % for each day
  final DateTime lastUpdated;
  
  FlareRiskPrediction({
    required this.riskPercentage,
    required this.daysUntilPeakRisk,
    required this.confidenceScore,
    required this.contributingFactors,
    required this.sevenDayForecast,
    required this.lastUpdated,
  });
  
  String getRiskLevel() {
    if (riskPercentage >= 70) return 'High';
    if (riskPercentage >= 50) return 'Medium';
    return 'Low';
  }
}
