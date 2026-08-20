import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

class AppleHealthAdapter implements WearableAdapter {
  @override
  WearableProvider get provider => WearableProvider.appleHealth;

  @override
  List<WearableScope> get supportedScopes => [
        WearableScope.sleep,
        WearableScope.hrv,
        WearableScope.activity,
        WearableScope.heartRate,
      ];

  /// Apple Health uses HealthKit (native); OAuth-style auth via Apple developer
  static const String authorizationUrl =
      'https://appleid.apple.com/auth/authorize';

  @override
  Future<String> authenticate() async {
    debugPrint('TODO: implement real OAuth for appleHealth');
    return 'mock_token_${provider.name}';
  }

  @override
  Future<DailyWearableAggregate?> fetchDaySummary(
      String token, String date) async {
    final r = Random(date.hashCode);
    return DailyWearableAggregate(
      uid: '',
      date: date,
      provider: provider,
      totalSleepMinutes: 390 + r.nextInt(90),
      deepSleepPercent: 18 + r.nextDouble() * 12,
      remSleepPercent: 20 + r.nextDouble() * 10,
      awakenings: r.nextInt(4),
      hrvNightly: 40 + r.nextDouble() * 50,
      restingHeartRate: 52 + r.nextInt(28),
      steps: 5000 + r.nextInt(10000),
      activeMinutes: 25 + r.nextInt(55),
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<String> refreshToken(String existingToken) async {
    return existingToken;
  }
}
