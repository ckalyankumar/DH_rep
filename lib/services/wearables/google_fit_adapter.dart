import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

class GoogleFitAdapter implements WearableAdapter {
  @override
  WearableProvider get provider => WearableProvider.googleFit;

  @override
  List<WearableScope> get supportedScopes => [
        WearableScope.sleep,
        WearableScope.hrv,
        WearableScope.activity,
        WearableScope.heartRate,
      ];

  static const String authorizationUrl =
      'https://accounts.google.com/o/oauth2/v2/auth';

  @override
  Future<String> authenticate() async {
    debugPrint('TODO: implement real OAuth for googleFit');
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
      totalSleepMinutes: 380 + r.nextInt(100),
      deepSleepPercent: 15 + r.nextDouble() * 15,
      remSleepPercent: 18 + r.nextDouble() * 12,
      awakenings: r.nextInt(5),
      hrvNightly: 37 + r.nextDouble() * 45,
      restingHeartRate: 55 + r.nextInt(25),
      steps: 5500 + r.nextInt(9500),
      activeMinutes: 32 + r.nextInt(48),
      syncedAt: DateTime.now(),
    );
  }

  @override
  Future<String> refreshToken(String existingToken) async {
    return existingToken;
  }
}
