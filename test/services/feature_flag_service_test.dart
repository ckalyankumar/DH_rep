import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/config/feature_flags.dart';
import 'package:dhealth/services/feature_flag_service.dart';

Future<FeatureFlags> _firstFlags(FeatureFlagService service) {
  return service.flags.first.timeout(const Duration(seconds: 2));
}

void main() {
  group('FeatureFlagService', () {
    test('missing document resolves to code defaults', () async {
      final db = FakeFirebaseFirestore();
      final service = FeatureFlagService(firestore: db);
      addTearDown(service.dispose);

      final flags = await _firstFlags(service);
      expect(flags, FeatureFlags.defaults);
      expect(service.current.showRecommendations, isFalse);
    });

    test('present document applies remote bools', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection(FeatureFlags.firestoreCollection)
          .doc(FeatureFlags.firestoreDocumentId)
          .set({
        FeatureFlags.showRiskScoreKey: false,
        FeatureFlags.showRedFlagsKey: true,
        FeatureFlags.showTriggerInsightsKey: false,
        FeatureFlags.showRecommendationsKey: true,
      });

      final service = FeatureFlagService(firestore: db);
      addTearDown(service.dispose);

      final flags = await _firstFlags(service);
      expect(flags.showRiskScore, isFalse);
      expect(flags.showRedFlags, isTrue);
      expect(flags.showTriggerInsights, isFalse);
      expect(flags.showRecommendations, isTrue);
    });

    test('malformed remote fields fall back per-flag', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection(FeatureFlags.firestoreCollection)
          .doc(FeatureFlags.firestoreDocumentId)
          .set({
        FeatureFlags.showRiskScoreKey: 'on',
        FeatureFlags.showRecommendationsKey: true,
      });

      final service = FeatureFlagService(firestore: db);
      addTearDown(service.dispose);

      final flags = await _firstFlags(service);
      expect(flags.showRiskScore, isTrue);
      expect(flags.showRedFlags, isTrue);
      expect(flags.showTriggerInsights, isTrue);
      expect(flags.showRecommendations, isTrue);
    });

    test('deleting the document returns to defaults', () async {
      final db = FakeFirebaseFirestore();
      final doc = db
          .collection(FeatureFlags.firestoreCollection)
          .doc(FeatureFlags.firestoreDocumentId);
      await doc.set({
        FeatureFlags.showRecommendationsKey: true,
        FeatureFlags.showRiskScoreKey: false,
      });

      final service = FeatureFlagService(firestore: db);
      addTearDown(service.dispose);

      final first = await _firstFlags(service);
      expect(first.showRecommendations, isTrue);
      expect(first.showRiskScore, isFalse);

      // Subscribe before delete so the broadcast snapshot is not dropped.
      final afterDelete = service.flags
          .firstWhere((f) => f == FeatureFlags.defaults)
          .timeout(const Duration(seconds: 2));
      await doc.delete();
      expect(await afterDelete, FeatureFlags.defaults);
    });

    test('live update is published to listeners', () async {
      final db = FakeFirebaseFirestore();
      await db
          .collection(FeatureFlags.firestoreCollection)
          .doc(FeatureFlags.firestoreDocumentId)
          .set({FeatureFlags.showRecommendationsKey: false});

      final service = FeatureFlagService(firestore: db);
      addTearDown(service.dispose);
      await _firstFlags(service);

      final next = service.flags.first.timeout(const Duration(seconds: 2));
      await db
          .collection(FeatureFlags.firestoreCollection)
          .doc(FeatureFlags.firestoreDocumentId)
          .update({FeatureFlags.showRecommendationsKey: true});

      expect((await next).showRecommendations, isTrue);
    });
  });
}
