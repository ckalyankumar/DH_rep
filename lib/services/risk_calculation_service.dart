import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/prediction_model.dart';

class RiskCalculationService {
  /// Calculate flare risk based on most recent daily log
  static double calculateFlareRisk(List<DailyLog> logs) {
    if (logs.isEmpty) return 50.0; // Default neutral risk
    
    final recentLogs = logs.take(7).toList(); // Last 7 days
    double baseRisk = 50.0;
    
    for (final log in recentLogs) {
      // Stress contribution (0-30 points)
      baseRisk += (log.stressLevel / 10) * 3;
      
      // Itch intensity contribution (0-25 points)
      baseRisk += (log.itchIntensity / 10) * 2.5;
      
      // Sleep quality contribution (-15 to 0 points)
      if (log.sleepQuality <= 2) {
        baseRisk += 15;
      } else if (log.sleepQuality == 3) {
        baseRisk += 5;
      }
      
      // Sleep disruption contribution (0-10 points)
      if (log.sleepDisruption) {
        baseRisk += 10;
      }
    }
    
    // Average across days and cap
    double averageRisk = baseRisk / recentLogs.length;
    return (averageRisk).clamp(10.0, 95.0);
  }
  
  /// Get contributing risk factors from logs
  static List<PredictionFactor> getContributingFactors(
    List<DailyLog> logs,
    String condition,
  ) {
    if (logs.isEmpty) return [];
    
    final recentLog = logs.first;
    final factors = <PredictionFactor>[];
    
    // High stress detection
    if (recentLog.stressLevel >= 7) {
      factors.add(PredictionFactor(
        name: 'Stress Level',
        value: '${recentLog.stressLevel}/10 (High)',
        impact: RiskLevel.high,
      ));
    }
    
    // High itch detection
    if (recentLog.itchIntensity >= 7) {
      factors.add(PredictionFactor(
        name: 'Itch Intensity',
        value: '${recentLog.itchIntensity}/10 (High)',
        impact: RiskLevel.high,
      ));
    }
    
    // Poor sleep detection
    if (recentLog.sleepQuality <= 2 || recentLog.sleepDisruption) {
      factors.add(PredictionFactor(
        name: 'Sleep Quality',
        value: '${recentLog.sleepQuality}/5 (Poor)',
        impact: RiskLevel.high,
      ));
    }
    
    // Lesion severity
    if (recentLog.lesionSeverity != 'none') {
      factors.add(PredictionFactor(
        name: 'Visible Lesions',
        value: recentLog.lesionSeverity.toUpperCase(),
        impact: recentLog.lesionSeverity == 'severe' 
            ? RiskLevel.high 
            : RiskLevel.medium,
      ));
    }
    
    // Affected areas count
    if (recentLog.affectedAreas.isNotEmpty) {
      factors.add(PredictionFactor(
        name: 'Affected Areas',
        value: '${recentLog.affectedAreas.length} areas',
        impact: recentLog.affectedAreas.length > 3 
            ? RiskLevel.high 
            : RiskLevel.medium,
      ));
    }
    
    return factors;
  }
  
  /// Generate 7-day risk forecast
  static List<int> generateSevenDayForecast(double currentRisk) {
    final forecast = <int>[];
    double trend = currentRisk;
    
    for (int i = 0; i < 7; i++) {
      // Simulate trend with slight daily variation
      trend += (i == 3 ? 4 : -0.5); // Peak on day 4
      forecast.add((trend).clamp(10, 95).toInt());
    }
    
    return forecast;
  }
  
  /// Calculate streak based on logs
  static int calculateStreak(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    
    int streak = 0;
    DateTime currentDate = DateTime.now();
    
    for (final log in logs) {
      if (currentDate.difference(log.date).inDays == streak) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }
}
