import 'package:flutter_test/flutter_test.dart';
import 'package:dhealth/models/daily_log.dart';

void main() {
  group('DailyLog Model Tests', () {
    test('DailyLog should create instance correctly', () {
      final log = DailyLog(
        id: '1',
        date: DateTime(2025, 11, 26),
        condition: 'psoriasis',
        mood: 3,
        itchIntensity: 5,
        stressLevel: 6,
        lesionSeverity: 'mild',
        affectedAreas: ['face', 'scalp'],
        sleepQuality: 3,
        sleepDisruption: false,
        notes: 'Test notes',
      );

      expect(log.id, '1');
      expect(log.condition, 'psoriasis');
      expect(log.mood, 3);
      expect(log.itchIntensity, 5);
      expect(log.stressLevel, 6);
      expect(log.lesionSeverity, 'mild');
      expect(log.affectedAreas.length, 2);
      expect(log.sleepQuality, 3);
      expect(log.sleepDisruption, false);
      expect(log.notes, 'Test notes');
    });

    test('DailyLog toJson should return correct map', () {
      final log = DailyLog(
        id: '1',
        date: DateTime(2025, 11, 26),
        condition: 'psoriasis',
        mood: 4,
        itchIntensity: 7,
        stressLevel: 8,
        lesionSeverity: 'moderate',
        affectedAreas: ['arms', 'legs'],
        sleepQuality: 4,
        sleepDisruption: true,
        notes: 'Flare triggered',
      );

      final json = log.toJson();

      expect(json['id'], '1');
      expect(json['condition'], 'psoriasis');
      expect(json['mood'], 4);
      expect(json['itchIntensity'], 7);
      expect(json['stressLevel'], 8);
      expect(json['sleepQuality'], 4);
      expect(json['sleepDisruption'], true);
    });

    test('DailyLog fromJson should create instance from map', () {
      final json = {
        'id': '2',
        'date': '2025-11-26T10:30:00.000Z',
        'condition': 'eczema',
        'mood': 2,
        'itchIntensity': 9,
        'stressLevel': 5,
        'lesionSeverity': 'severe',
        'affectedAreas': ['face', 'hands'],
        'sleepQuality': 2,
        'sleepDisruption': true,
        'notes': 'Very bad day',
      };

      final log = DailyLog.fromJson(json);

      expect(log.id, '2');
      expect(log.condition, 'eczema');
      expect(log.mood, 2);
      expect(log.itchIntensity, 9);
      expect(log.stressLevel, 5);
      expect(log.lesionSeverity, 'severe');
      expect(log.sleepDisruption, true);
    });

    test('DailyLog validation - itch intensity bounds', () {
      expect(
        () => DailyLog(
          id: '1',
          date: DateTime.now(),
          condition: 'psoriasis',
          mood: 3,
          itchIntensity: 11, // Out of bounds
          stressLevel: 5,
          lesionSeverity: 'mild',
          affectedAreas: [],
          sleepQuality: 3,
          sleepDisruption: false,
          notes: '',
        ),
        returnsNormally,
      );
    });

    test('DailyLog validation - stress level bounds', () {
      expect(
        () => DailyLog(
          id: '1',
          date: DateTime.now(),
          condition: 'psoriasis',
          mood: 3,
          itchIntensity: 5,
          stressLevel: -1, // Out of bounds
          lesionSeverity: 'mild',
          affectedAreas: [],
          sleepQuality: 3,
          sleepDisruption: false,
          notes: '',
        ),
        returnsNormally,
      );
    });

    test('DailyLog affected areas list handling', () {
      final log = DailyLog(
        id: '1',
        date: DateTime.now(),
        condition: 'psoriasis',
        mood: 3,
        itchIntensity: 5,
        stressLevel: 6,
        lesionSeverity: 'moderate',
        affectedAreas: ['face', 'scalp', 'torso', 'arms', 'legs'],
        sleepQuality: 3,
        sleepDisruption: false,
        notes: 'Multiple areas affected',
      );

      expect(log.affectedAreas.length, 5);
      expect(log.affectedAreas.contains('face'), true);
      expect(log.affectedAreas.contains('feet'), false);
    });
  });

  group('DailyLog Edge Cases', () {
    test('DailyLog with empty notes', () {
      final log = DailyLog(
        id: '1',
        date: DateTime.now(),
        condition: 'eczema',
        mood: 5,
        itchIntensity: 0,
        stressLevel: 0,
        lesionSeverity: 'none',
        affectedAreas: [],
        sleepQuality: 5,
        sleepDisruption: false,
        notes: '',
      );

      expect(log.notes, '');
      expect(log.affectedAreas.isEmpty, true);
    });

    test('DailyLog with very long notes', () {
      final longNotes =
          'A' * 1000; // 1000 character note
      final log = DailyLog(
        id: '1',
        date: DateTime.now(),
        condition: 'psoriasis',
        mood: 3,
        itchIntensity: 5,
        stressLevel: 6,
        lesionSeverity: 'mild',
        affectedAreas: ['face'],
        sleepQuality: 3,
        sleepDisruption: false,
        notes: longNotes,
      );

      expect(log.notes.length, 1000);
    });
  });
}
