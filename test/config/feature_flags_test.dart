import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/config/feature_flags.dart';

void main() {
  group('FeatureFlags.defaults', () {
    test('matches the agreed CDSCO-pending defaults', () {
      expect(FeatureFlags.defaults.showRiskScore, isTrue);
      expect(FeatureFlags.defaults.showRedFlags, isTrue);
      expect(FeatureFlags.defaults.showTriggerInsights, isTrue);
      expect(FeatureFlags.defaults.showRecommendations, isFalse);
    });
  });

  group('FeatureFlags.fromMap', () {
    test('null map returns defaults', () {
      expect(FeatureFlags.fromMap(null), FeatureFlags.defaults);
    });

    test('empty map returns defaults', () {
      expect(FeatureFlags.fromMap(const {}), FeatureFlags.defaults);
    });

    test('valid bools override defaults, including explicit false', () {
      final flags = FeatureFlags.fromMap(const {
        'showRiskScore': false,
        'showRedFlags': false,
        'showTriggerInsights': false,
        'showRecommendations': true,
      });
      expect(flags.showRiskScore, isFalse);
      expect(flags.showRedFlags, isFalse);
      expect(flags.showTriggerInsights, isFalse);
      expect(flags.showRecommendations, isTrue);
    });

    test('malformed field types fall back per-flag, not for the whole doc', () {
      final flags = FeatureFlags.fromMap({
        'showRiskScore': 'yes',
        'showRedFlags': 1,
        'showTriggerInsights': null,
        'showRecommendations': true,
      });
      expect(flags.showRiskScore, FeatureFlags.defaults.showRiskScore);
      expect(flags.showRedFlags, FeatureFlags.defaults.showRedFlags);
      expect(
        flags.showTriggerInsights,
        FeatureFlags.defaults.showTriggerInsights,
      );
      expect(flags.showRecommendations, isTrue);
    });

    test('unknown keys are ignored', () {
      final flags = FeatureFlags.fromMap(const {
        'showRiskScore': false,
        'unrelatedExperimentalFlag': true,
      });
      expect(flags.showRiskScore, isFalse);
      expect(flags.showRedFlags, isTrue);
      expect(flags.showTriggerInsights, isTrue);
      expect(flags.showRecommendations, isFalse);
    });
  });
}
