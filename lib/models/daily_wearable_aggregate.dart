import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dhealth/models/wearable_source.dart';

/// Daily aggregate of wearable data. Stored at users/{uid}/dailyWearableAggregates/{date}
class DailyWearableAggregate {
  final String uid;
  final String date; // yyyy-MM-dd
  final WearableProvider provider;
  final int? totalSleepMinutes;
  final double? deepSleepPercent;
  final double? remSleepPercent;
  final int? awakenings;
  final int? sleepScore; // 0–100 if provider supplies one
  final double? hrvNightly; // ms
  final int? hrvReadiness; // 0–100 Oura-style
  final int? restingHeartRate; // bpm
  final int? steps;
  final int? activeMinutes;
  final double? deviceStressScore; // Garmin only
  final DateTime syncedAt;

  const DailyWearableAggregate({
    required this.uid,
    required this.date,
    required this.provider,
    this.totalSleepMinutes,
    this.deepSleepPercent,
    this.remSleepPercent,
    this.awakenings,
    this.sleepScore,
    this.hrvNightly,
    this.hrvReadiness,
    this.restingHeartRate,
    this.steps,
    this.activeMinutes,
    this.deviceStressScore,
    required this.syncedAt,
  });

  bool get hasSleepData => totalSleepMinutes != null;
  bool get hasHrvData => hrvNightly != null || hrvReadiness != null;

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'date': date,
      'provider': provider.name,
      if (totalSleepMinutes != null) 'totalSleepMinutes': totalSleepMinutes,
      if (deepSleepPercent != null) 'deepSleepPercent': deepSleepPercent,
      if (remSleepPercent != null) 'remSleepPercent': remSleepPercent,
      if (awakenings != null) 'awakenings': awakenings,
      if (sleepScore != null) 'sleepScore': sleepScore,
      if (hrvNightly != null) 'hrvNightly': hrvNightly,
      if (hrvReadiness != null) 'hrvReadiness': hrvReadiness,
      if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
      if (steps != null) 'steps': steps,
      if (activeMinutes != null) 'activeMinutes': activeMinutes,
      if (deviceStressScore != null) 'deviceStressScore': deviceStressScore,
      'syncedAt': syncedAt.toIso8601String(),
    };
  }

  static DailyWearableAggregate fromFirestore(Map<String, dynamic> data) {
    return DailyWearableAggregate(
      uid: data['uid'] as String? ?? '',
      date: data['date'] as String? ?? '',
      provider: WearableProvider.values.byName(
        data['provider'] as String? ?? WearableProvider.fitbit.name,
      ),
      totalSleepMinutes: data['totalSleepMinutes'] as int?,
      deepSleepPercent: (data['deepSleepPercent'] as num?)?.toDouble(),
      remSleepPercent: (data['remSleepPercent'] as num?)?.toDouble(),
      awakenings: data['awakenings'] as int?,
      sleepScore: data['sleepScore'] as int?,
      hrvNightly: (data['hrvNightly'] as num?)?.toDouble(),
      hrvReadiness: data['hrvReadiness'] as int?,
      restingHeartRate: data['restingHeartRate'] as int?,
      steps: data['steps'] as int?,
      activeMinutes: data['activeMinutes'] as int?,
      deviceStressScore: (data['deviceStressScore'] as num?)?.toDouble(),
      syncedAt: _parseDateTime(data['syncedAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  DailyWearableAggregate copyWith({
    String? uid,
    String? date,
    WearableProvider? provider,
    int? totalSleepMinutes,
    double? deepSleepPercent,
    double? remSleepPercent,
    int? awakenings,
    int? sleepScore,
    double? hrvNightly,
    int? hrvReadiness,
    int? restingHeartRate,
    int? steps,
    int? activeMinutes,
    double? deviceStressScore,
    DateTime? syncedAt,
  }) {
    return DailyWearableAggregate(
      uid: uid ?? this.uid,
      date: date ?? this.date,
      provider: provider ?? this.provider,
      totalSleepMinutes: totalSleepMinutes ?? this.totalSleepMinutes,
      deepSleepPercent: deepSleepPercent ?? this.deepSleepPercent,
      remSleepPercent: remSleepPercent ?? this.remSleepPercent,
      awakenings: awakenings ?? this.awakenings,
      sleepScore: sleepScore ?? this.sleepScore,
      hrvNightly: hrvNightly ?? this.hrvNightly,
      hrvReadiness: hrvReadiness ?? this.hrvReadiness,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      steps: steps ?? this.steps,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      deviceStressScore: deviceStressScore ?? this.deviceStressScore,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
