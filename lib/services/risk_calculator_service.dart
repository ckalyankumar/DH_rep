import '../models/daily_log.dart';
import 'log_storage_service.dart';

class RiskCalculatorService {
  final LogStorageService _logService = LogStorageService();
  
  // Calculate current flare risk based on recent logs
  Future<int> calculateFlareRisk(String conditionId) async {
    final logs = await _logService.getLogsByCondition(conditionId);
    
    if (logs.isEmpty) return 50; // Default moderate risk
    
    // Get last 7 days of logs
    final recentLogs = logs.take(7).toList();
    
    // Calculate weighted average
    double totalRisk = 0;
    double totalWeight = 0;
    
    for (int i = 0; i < recentLogs.length; i++) {
      final weight = 1.0 / (i + 1); // More recent = higher weight
      totalRisk += recentLogs[i].calculateRiskScore() * weight;
      totalWeight += weight;
    }
    
    int avgRisk = (totalRisk / totalWeight).round();
    
    // Apply trend adjustment
    if (recentLogs.length >= 3) {
      final trend = _calculateTrend(recentLogs.take(3).toList());
      if (trend > 0) avgRisk += 5; // Worsening
      if (trend < 0) avgRisk -= 5; // Improving
    }
    
    return avgRisk.clamp(0, 100);
  }
  
  // Calculate trend (positive = worsening, negative = improving)
  int _calculateTrend(List<DailyLog> logs) {
    if (logs.length < 2) return 0;
    
    final oldScore = logs.last.calculateRiskScore();
    final newScore = logs.first.calculateRiskScore();
    
    return newScore - oldScore;
  }
  
  // Predict 7-day forecast
  Future<List<int>> predict7DayRisk(String conditionId) async {
    final currentRisk = await calculateFlareRisk(conditionId);
    final logs = await _logService.getLogsByCondition(conditionId);
    
    List<int> forecast = [currentRisk];
    
    // Simple linear projection based on trend
    if (logs.length >= 7) {
      final trend = _calculateTrend(logs.take(7).toList()) ~/ 7;
      
      for (int i = 1; i < 7; i++) {
        int predictedRisk = currentRisk + (trend * i);
        forecast.add(predictedRisk.clamp(20, 95));
      }
    } else {
      // Not enough data, flat projection with slight variation
      for (int i = 1; i < 7; i++) {
        forecast.add((currentRisk + (i % 2 == 0 ? 2 : -2)).clamp(20, 95));
      }
    }
    
    return forecast;
  }
  
  // Identify top risk factors
  Future<List<Map<String, dynamic>>> identifyRiskFactors(String conditionId) async {
    final logs = await _logService.getLogsByCondition(conditionId);
    if (logs.isEmpty) return [];
    
    final recentLogs = logs.take(7).toList();
    
    // Calculate averages
    final avgStress = recentLogs.map((l) => l.stressLevel).reduce((a, b) => a + b) / recentLogs.length;
    final avgItch = recentLogs.map((l) => l.itchIntensity).reduce((a, b) => a + b) / recentLogs.length;
    final avgSleep = recentLogs.map((l) => l.sleepQuality).reduce((a, b) => a + b) / recentLogs.length;
    final sleepDisruptionCount = recentLogs.where((l) => l.sleepDisruption).length;
    
    List<Map<String, dynamic>> factors = [];
    
    // Stress factor
    if (avgStress >= 7) {
      factors.add({
        'name': 'High Stress Level',
        'value': 'Average ${avgStress.toStringAsFixed(1)}/10',
        'impact': 'high',
      });
    } else if (avgStress >= 5) {
      factors.add({
        'name': 'Moderate Stress',
        'value': 'Average ${avgStress.toStringAsFixed(1)}/10',
        'impact': 'medium',
      });
    }
    
    // Itch factor
    if (avgItch >= 7) {
      factors.add({
        'name': 'Severe Itching',
        'value': 'Average ${avgItch.toStringAsFixed(1)}/10',
        'impact': 'high',
      });
    }
    
    // Sleep factor
    if (avgSleep <= 2 || sleepDisruptionCount >= 3) {
      factors.add({
        'name': 'Poor Sleep Quality',
        'value': '$sleepDisruptionCount nights disrupted',
        'impact': 'high',
      });
    }
    
    // Add generic factors if not enough specific ones
    if (factors.length < 3) {
      factors.addAll([
        {'name': 'Weather Conditions', 'value': 'Monitor closely', 'impact': 'medium'},
        {'name': 'Medication Adherence', 'value': 'Track daily', 'impact': 'low'},
      ]);
    }
    
    return factors;
  }
}
