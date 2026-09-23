import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/config/feature_flags.dart';
import 'package:dhealth/services/feature_flag_service.dart';

/// Throws synchronously from the first call the service makes, standing in for
/// FirebaseFirestore.instance / .snapshots() failing during setup.
class _ThrowingFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw StateError('firestore unavailable');
  }
}

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
      expect(service.current.showRiskScore, isFalse);
      expect(service.current.showRedFlags, isFalse);
      expect(service.current.showTriggerInsights, isFalse);
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
      expect(flags.showRiskScore, isFalse);
      expect(flags.showRedFlags, isFalse);
      expect(flags.showTriggerInsights, isFalse);
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

    test('synchronous throw during listener setup fails closed', () async {
      late FeatureFlagService service;
      expect(
        () => service = FeatureFlagService(firestore: _ThrowingFirestore()),
        returnsNormally,
      );
      addTearDown(service.dispose);

      expect(service.current, FeatureFlags.defaults);
      expect(service.current.showRiskScore, isFalse);
      expect(service.current.showRedFlags, isFalse);
      expect(service.current.showTriggerInsights, isFalse);
      expect(service.current.showRecommendations, isFalse);
      await expectLater(service.dispose(), completes);
    });

    test('no Firebase app initialised: default instance fails closed', () {
      late FeatureFlagService service;
      expect(() => service = FeatureFlagService(), returnsNormally);
      addTearDown(service.dispose);

      expect(service.current, FeatureFlags.defaults);
    });
  });
}
