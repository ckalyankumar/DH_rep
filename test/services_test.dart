import 'package:flutter_test/flutter_test.dart';
import 'package:dhealth/services/prediction_service.dart';

void main() {
  group('PredictionService Tests', () {
    late PredictionService predictionService;

    setUp(() {
      predictionService = PredictionService();
    });

    test('calculateFlareRisk returns value between 0-100', () {
      final risk = predictionService.calculateFlareRisk(
        itchIntensity: 7,
        stressLevel: 8,
        sleepQuality: 2,
        sleepDisruption: true,
        affectedAreas: ['arm'],
        lesionSeverity: 'moderate',
      );

      expect(risk, greaterThanOrEqualTo(0));
      expect(risk, lessThanOrEqualTo(100));
    });

    test('High stress and itch should increase flare risk', () {
      final lowRisk = predictionService.calculateFlareRisk(
        itchIntensity: 1,
        stressLevel: 1,
        sleepQuality: 5,
        sleepDisruption: false,
        affectedAreas: [],
        lesionSeverity: 'none',
      );

      final highRisk = predictionService.calculateFlareRisk(
        itchIntensity: 10,
        stressLevel: 10,
        sleepQuality: 1,
        sleepDisruption: true,
        affectedAreas: ['arm', 'leg', 'torso'],
        lesionSeverity: 'severe',
      );

      expect(highRisk, greaterThan(lowRisk));
    });

    test('Perfect health metrics should return low risk', () {
      final risk = predictionService.calculateFlareRisk(
        itchIntensity: 0,
        stressLevel: 0,
        sleepQuality: 5,
        sleepDisruption: false,
        affectedAreas: [],
        lesionSeverity: 'none',
      );

      expect(risk, lessThan(30));
    });

    test('Poor health metrics should return high risk', () {
      final risk = predictionService.calculateFlareRisk(
        itchIntensity: 10,
        stressLevel: 10,
        sleepQuality: 1,
        sleepDisruption: true,
        affectedAreas: ['arm', 'leg'],
        lesionSeverity: 'severe',
      );

      expect(risk, greaterThan(70));
    });

    test('getRiskLevel returns correct category', () {
      expect(predictionService.getRiskLevel(25), 'low');
      expect(predictionService.getRiskLevel(50), 'medium');
      expect(predictionService.getRiskLevel(75), 'high');
    });

    test('getRecommendationPriority returns correct priority', () {
      expect(predictionService.getRecommendationPriority(0.9), 'high');
      expect(predictionService.getRecommendationPriority(0.6), 'medium');
      expect(predictionService.getRecommendationPriority(0.2), 'low');
    });
  });

  group('PredictionService Edge Cases', () {
    late PredictionService predictionService;

    setUp(() {
      predictionService = PredictionService();
    });

    test('Handles minimum values', () {
      final risk = predictionService.calculateFlareRisk(
        itchIntensity: 0,
        stressLevel: 0,
        sleepQuality: 5,
        sleepDisruption: false,
        affectedAreas: [],
        lesionSeverity: 'none',
      );

      expect(risk, isNotNull);
      expect(risk, greaterThanOrEqualTo(0));
    });

    test('Handles maximum values', () {
      final risk = predictionService.calculateFlareRisk(
        itchIntensity: 10,
        stressLevel: 10,
        sleepQuality: 1,
        sleepDisruption: true,
        affectedAreas: ['arm', 'leg', 'torso', 'face'],
        lesionSeverity: 'severe',
      );

      expect(risk, isNotNull);
      expect(risk, lessThanOrEqualTo(100));
    });
  });
}
