import 'dart:convert';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/services/fhir_bundle_generator.dart';
import 'package:flutter_test/flutter_test.dart';

DailyLog _log({
  required int itch,
  required int mood,
  String notes = 'evening flare on elbows',
}) {
  return DailyLog(
    id: 'log-1',
    condition: 'psoriasis',
    mood: mood,
    itchIntensity: itch,
    stressLevel: 6,
    lesionSeverity: 'moderate',
    affectedAreas: const ['elbow'],
    sleepQuality: 2,
    sleepDisruption: true,
    notes: notes,
    date: DateTime(2026, 4, 1),
  );
}

void main() {
  test('default bundle includes risk-score and logged symptom fields', () {
    final bundle = FHIRBundleGenerator.generateFHIRBundle(
      patientId: 'user-1',
      patientName: 'Test Patient',
      condition: 'psoriasis',
      logs: [_log(itch: 8, mood: 2)],
      reportDate: DateTime(2026, 4, 2),
    );
    final json = jsonEncode(bundle);

    expect(json.contains('risk-score'), isTrue);
    expect(json.contains('Risk Assessment Score'), isTrue);
    expect(json.contains('Mood'), isTrue);
    expect(json.contains('Symptom intensity'), isTrue);
    expect(json.contains('Stress level'), isTrue);
    expect(json.contains('Sleep quality'), isTrue);
    expect(json.contains('evening flare on elbows'), isTrue);
  });

  test('includeRiskScore false omits risk-score and keeps logged fields', () {
    final bundle = FHIRBundleGenerator.generateFHIRBundle(
      patientId: 'user-1',
      patientName: 'Test Patient',
      condition: 'psoriasis',
      logs: [_log(itch: 9, mood: 1)],
      reportDate: DateTime(2026, 4, 2),
      includeRiskScore: false,
    );
    final json = jsonEncode(bundle);

    expect(json.contains('risk-score'), isFalse);
    expect(json.contains('Risk Assessment Score'), isFalse);
    expect(json.contains('http://abdm.gov.in/CodeSystem/risk-score'), isFalse);
    expect(json.contains('Mood'), isTrue);
    expect(json.contains('Symptom intensity'), isTrue);
    expect(json.contains('Stress level'), isTrue);
    expect(json.contains('Sleep quality'), isTrue);
    expect(json.contains('evening flare on elbows'), isTrue);
  });
}
