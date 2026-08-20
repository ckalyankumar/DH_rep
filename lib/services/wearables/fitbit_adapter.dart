import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

class FitbitAdapter implements WearableAdapter {
  @override
  WearableProvider get provider => WearableProvider.fitbit;

  @override
  List<WearableScope> get supportedScopes => [
        WearableScope.sleep,
        WearableScope.hrv,
        WearableScope.activity,
        WearableScope.heartRate,
      ];

  static const String authorizationUrl =
      'https://www.fitbit.com/oauth2/authorize';

  @override
  Future<String> authenticate() async {
    debugPrint('TODO: implement real OAuth for fitbit');
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
      totalSleepMinutes: 360 + r.nextInt(120),
      deepSleepPercent: 15 + r.nextDouble() * 15,
      remSleepPercent: 18 + r.nextDouble() * 12,
      awakenings: r.nextInt(5),
      sleepScore: 65 + r.nextInt(30),
      hrvNightly: 35 + r.nextDouble() * 45,
      restingHeartRate: 55 + r.nextInt(25),
      steps: 4000 + r.nextInt(8000),
      activeMinutes: 20 + r.nextInt(60),
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<String> refreshToken(String existingToken) async {
    return existingToken;
  }
}
