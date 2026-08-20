import 'package:dhealth/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile toMap/fromMap', () {
    test('dateOfBirth round-trips as date-only string', () {
      final original = UserProfile(
        userId: 'user-1',
        name: 'Test User',
        selectedCondition: 'psoriasis',
        createdAt: DateTime.utc(2024, 1, 1, 10, 30),
        lastUpdated: DateTime.utc(2024, 1, 2, 9, 0),
        currentStreak: 3,
        longestStreak: 5,
        lastLogDate: DateTime.utc(2024, 1, 3, 8, 0),
        dateOfBirth: DateTime.utc(1990, 1, 15, 12, 45),
        abhaId: '12-3456-7890-1234',
      );

      final map = original.toMap();

      expect(map['dateOfBirth'], '1990-01-15');
      final roundTripped = UserProfile.fromMap(map);
      expect(roundTripped.dateOfBirth, DateTime(1990, 1, 15));
      expect(roundTripped.abhaId, original.abhaId);
    });

    test('missing optional keys deserialize as null', () {
      final map = {
        'userId': 'user-2',
        'name': 'Another User',
        'selectedCondition': 'eczema',
        'createdAt': DateTime.utc(2024, 1, 1).toIso8601String(),
        'lastUpdated': DateTime.utc(2024, 1, 2).toIso8601String(),
        'currentStreak': 0,
        'longestStreak': 0,
        'lastLogDate': null,
        // dateOfBirth and abhaId intentionally omitted
      };

      final profile = UserProfile.fromMap(map);
      expect(profile.dateOfBirth, isNull);
      expect(profile.abhaId, isNull);
    });
  });

  group('UserProfile copyWith', () {
    test('preserves unmodified fields when only one is changed', () {
      final base = UserProfile(
        userId: 'user-3',
        name: 'Base User',
        selectedCondition: 'psoriasis',
        createdAt: DateTime.utc(2024, 1, 1),
        lastUpdated: DateTime.utc(2024, 1, 2),
        currentStreak: 1,
        longestStreak: 2,
        lastLogDate: DateTime.utc(2024, 1, 3),
        dateOfBirth: DateTime.utc(1995, 5, 10),
        abhaId: '11-1111-1111-1111',
      );

      final updatedDob = DateTime.utc(1996, 6, 11);
      final updated = base.copyWith(dateOfBirth: updatedDob);

      expect(updated.userId, base.userId);
      expect(updated.name, base.name);
      expect(updated.selectedCondition, base.selectedCondition);
      expect(updated.createdAt, base.createdAt);
      expect(updated.lastUpdated, base.lastUpdated);
      expect(updated.currentStreak, base.currentStreak);
      expect(updated.longestStreak, base.longestStreak);
      expect(updated.lastLogDate, base.lastLogDate);
      expect(updated.abhaId, base.abhaId);
      expect(updated.dateOfBirth, updatedDob);
    });
  });
}

