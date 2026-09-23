import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/config/feature_flags.dart';

const _allOff = FeatureFlags(
  showRiskScore: false,
  showRedFlags: false,
  showTriggerInsights: false,
  showRecommendations: false,
);

void main() {
  group('FeatureFlags.defaults', () {
    test('fail closed: every interpretive feature is off', () {
      expect(FeatureFlags.defaults.showRiskScore, isFalse);
      expect(FeatureFlags.defaults.showRedFlags, isFalse);
      expect(FeatureFlags.defaults.showTriggerInsights, isFalse);
      expect(FeatureFlags.defaults.showRecommendations, isFalse);
      expect(FeatureFlags.defaults, _allOff);
    });
  });

  group('FeatureFlags.fromMap', () {
    test('null doc resolves to all false', () {
      expect(FeatureFlags.fromMap(null), _allOff);
    });

    test('empty map resolves to all false', () {
      expect(FeatureFlags.fromMap(const {}), _allOff);
    });

    test('partial map enables only the fields present; missing stay false',
        () {
      final flags = FeatureFlags.fromMap(const {
        'showRiskScore': true,
        'showRecommendations': true,
      });
      expect(flags.showRiskScore, isTrue);
      expect(flags.showRedFlags, isFalse);
      expect(flags.showTriggerInsights, isFalse);
      expect(flags.showRecommendations, isTrue);
    });

    test('wrong types resolve to false per-flag, not for the whole doc', () {
      final flags = FeatureFlags.fromMap({
        'showRiskScore': 'true',
        'showRedFlags': 1,
        'showTriggerInsights': null,
        'showRecommendations': true,
      });
      expect(flags.showRiskScore, isFalse);
      expect(flags.showRedFlags, isFalse);
      expect(flags.showTriggerInsights, isFalse);
      expect(flags.showRecommendations, isTrue);
    });

    test('truthy non-bool values never enable a flag', () {
      final flags = FeatureFlags.fromMap({
        'showRiskScore': 'yes',
        'showRedFlags': 1.0,
        'showTriggerInsights': const ['true'],
        'showRecommendations': const {'enabled': true},
      });
      expect(flags, _allOff);
    });

    test('all-true map enables every flag', () {
      final flags = FeatureFlags.fromMap(const {
        'showRiskScore': true,
        'showRedFlags': true,
        'showTriggerInsights': true,
        'showRecommendations': true,
      });
      expect(flags.showRiskScore, isTrue);
      expect(flags.showRedFlags, isTrue);
      expect(flags.showTriggerInsights, isTrue);
      expect(flags.showRecommendations, isTrue);
    });

    test('explicit false is respected', () {
      final flags = FeatureFlags.fromMap(const {
        'showRiskScore': false,
        'showRedFlags': false,
        'showTriggerInsights': false,
        'showRecommendations': false,
      });
      expect(flags, _allOff);
    });

    test('unknown keys are ignored', () {
      final flags = FeatureFlags.fromMap(const {
        'showRiskScore': true,
        'unrelatedExperimentalFlag': true,
      });
      expect(flags.showRiskScore, isTrue);
      expect(flags.showRedFlags, isFalse);
      expect(flags.showTriggerInsights, isFalse);
      expect(flags.showRecommendations, isFalse);
    });
  });
}
