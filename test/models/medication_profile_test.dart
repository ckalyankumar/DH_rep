import 'package:dhealth/models/medication_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MedicationProfile fromJson/toJson', () {
    test('round-trips cleanly with all fields present', () {
      final original = MedicationProfile(
        uid: 'user-123',
        treatmentType: MedicationTreatmentType.topical,
        medicationName: 'Calcipotriol',
        startDate: DateTime.utc(2024, 1, 15),
        updatedAt: DateTime.utc(2024, 2, 20, 10, 30),
      );

      final json = original.toJson();
      final roundTripped = MedicationProfile.fromJson(json);

      expect(roundTripped.uid, original.uid);
      expect(roundTripped.treatmentType, original.treatmentType);
      expect(roundTripped.medicationName, original.medicationName);
      expect(roundTripped.startDate, original.startDate);
      expect(roundTripped.updatedAt, original.updatedAt);
    });

    test('round-trips cleanly with optional fields null', () {
      final original = MedicationProfile(
        uid: 'user-456',
        treatmentType: MedicationTreatmentType.systemic,
        medicationName: null,
        startDate: null,
        updatedAt: DateTime.utc(2024, 3, 10, 8, 0),
      );

      final json = original.toJson();
      final roundTripped = MedicationProfile.fromJson(json);

      expect(roundTripped.uid, original.uid);
      expect(roundTripped.treatmentType, original.treatmentType);
      expect(roundTripped.medicationName, isNull);
      expect(roundTripped.startDate, isNull);
      expect(roundTripped.updatedAt, original.updatedAt);
    });
  });

  group('MedicationProfile copyWith', () {
    test('preserves unmodified fields', () {
      final base = MedicationProfile(
        uid: 'user-789',
        treatmentType: MedicationTreatmentType.topical,
        medicationName: 'Old name',
        startDate: DateTime.utc(2024, 4, 1),
        updatedAt: DateTime.utc(2024, 4, 2, 12, 0),
      );

      final updated = base.copyWith(
        treatmentType: MedicationTreatmentType.biologic,
        medicationName: 'New name',
      );

      expect(updated.uid, base.uid);
      expect(updated.treatmentType, MedicationTreatmentType.biologic);
      expect(updated.medicationName, 'New name');
      expect(updated.startDate, base.startDate);
      expect(updated.updatedAt, base.updatedAt);
    });
  });

  group('MedicationTreatmentType serialization', () {
    test('none serialises and deserialises correctly', () {
      final profile = MedicationProfile(
        uid: 'user-none',
        treatmentType: MedicationTreatmentType.none,
        medicationName: null,
        startDate: null,
        updatedAt: DateTime.utc(2024, 5, 5, 9, 0),
      );

      final json = profile.toJson();
      expect(json['treatmentType'], 'none');

      final roundTripped = MedicationProfile.fromJson(json);
      expect(roundTripped.treatmentType, MedicationTreatmentType.none);
    });
  });
}

