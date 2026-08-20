import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

class GarminAdapter implements WearableAdapter {
  @override
  WearableProvider get provider => WearableProvider.garmin;

  @override
  List<WearableScope> get supportedScopes => [
        WearableScope.sleep,
        WearableScope.hrv,
        WearableScope.activity,
        WearableScope.heartRate,
        WearableScope.stress,
      ];

  static const String authorizationUrl =
      'https://connect.garmin.com/oauthConfirm';

  @override
  Future<String> authenticate() async {
    debugPrint('TODO: implement real OAuth for garmin');
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
      totalSleepMinutes: 370 + r.nextInt(100),
      deepSleepPercent: 16 + r.nextDouble() * 14,
      remSleepPercent: 19 + r.nextDouble() * 11,
      awakenings: r.nextInt(6),
      sleepScore: 70 + r.nextInt(25),
      hrvNightly: 38 + r.nextDouble() * 42,
      restingHeartRate: 54 + r.nextInt(26),
      steps: 6000 + r.nextInt(7000),
      activeMinutes: 30 + r.nextInt(50),
      deviceStressScore: 20 + r.nextDouble() * 50,
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<String> refreshToken(String existingToken) async {
    return existingToken;
  }
}
