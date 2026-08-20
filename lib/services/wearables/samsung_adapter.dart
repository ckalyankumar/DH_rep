import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

class SamsungAdapter implements WearableAdapter {
  @override
  WearableProvider get provider => WearableProvider.samsungHealth;

  @override
  List<WearableScope> get supportedScopes => [
        WearableScope.sleep,
        WearableScope.hrv,
        WearableScope.activity,
        WearableScope.heartRate,
      ];

  /// Samsung Health uses Samsung Account OAuth
  static const String authorizationUrl =
      'https://account.samsung.com/accounts/v1/oauth2/authorize';

  @override
  Future<String> authenticate() async {
    debugPrint('TODO: implement real OAuth for samsungHealth');
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
      totalSleepMinutes: 375 + r.nextInt(95),
      deepSleepPercent: 16 + r.nextDouble() * 14,
      remSleepPercent: 19 + r.nextDouble() * 11,
      awakenings: r.nextInt(5),
      sleepScore: 68 + r.nextInt(27),
      hrvNightly: 36 + r.nextDouble() * 44,
      restingHeartRate: 56 + r.nextInt(24),
      steps: 4500 + r.nextInt(8500),
      activeMinutes: 28 + r.nextInt(52),
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<String> refreshToken(String existingToken) async {
    return existingToken;
  }
}
