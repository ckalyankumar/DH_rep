import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

class OuraAdapter implements WearableAdapter {
  @override
  WearableProvider get provider => WearableProvider.oura;

  @override
  List<WearableScope> get supportedScopes => [
        WearableScope.sleep,
        WearableScope.hrv,
        WearableScope.activity,
        WearableScope.heartRate,
        WearableScope.readiness,
      ];

  static const String authorizationUrl =
      'https://cloud.ouraring.com/oauth/authorize';

  @override
  Future<String> authenticate() async {
    debugPrint('TODO: implement real OAuth for oura');
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
      totalSleepMinutes: 400 + r.nextInt(80),
      deepSleepPercent: 17 + r.nextDouble() * 13,
      remSleepPercent: 21 + r.nextDouble() * 9,
      awakenings: r.nextInt(3),
      sleepScore: 72 + r.nextInt(23),
      hrvNightly: 42 + r.nextDouble() * 48,
      hrvReadiness: 70 + r.nextInt(25),
      restingHeartRate: 53 + r.nextInt(27),
      steps: 3500 + r.nextInt(9000),
      activeMinutes: 22 + r.nextInt(58),
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<String> refreshToken(String existingToken) async {
    return existingToken;
  }
}
