import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/oauth_token_set.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

/// Thin wrapper around the `health` plugin so [HealthConnectAdapter] can
/// be unit-tested without a live Health Connect / HealthKit channel.
abstract class HealthConnectClient {
  Future<void> configure();
  Future<bool> isAvailable();
  Future<void> promptInstall();
  Future<bool> requestAuthorization(List<HealthDataType> types);
  Future<void> requestExtendedReadAccess();
  Future<List<HealthDataPoint>> read({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  });
}

class PluginHealthConnectClient implements HealthConnectClient {
  final Health _health;

  PluginHealthConnectClient({Health? health}) : _health = health ?? Health();

  @override
  Future<void> configure() async {
    await _health.configure();
    await Permission.activityRecognition.request();
  }

  @override
  Future<bool> isAvailable() => _health.isHealthConnectAvailable();

  @override
  Future<void> promptInstall() => _health.installHealthConnect();

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types) =>
      _health.requestAuthorization(types);

  @override
  Future<void> requestExtendedReadAccess() async {
    try {
      if (!await _health.isHealthDataHistoryAuthorized()) {
        await _health.requestHealthDataHistoryAuthorization();
      }
    } catch (e) {
      debugPrint('Health Connect history permission request failed: $e');
    }
    try {
      if (!await _health.isHealthDataInBackgroundAuthorized()) {
        await _health.requestHealthDataInBackgroundAuthorization();
      }
    } catch (e) {
      debugPrint('Health Connect background permission request failed: $e');
    }
  }

  @override
  Future<List<HealthDataPoint>> read({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    return _health.getHealthDataFromTypes(
      types: types,
      startTime: startTime,
      endTime: endTime,
    );
  }
}

/// Android Health Connect adapter, shared by the UI's "Google Fit" and
/// "Samsung Health" slots ([WearableProvider.googleFit] /
/// [WearableProvider.samsungHealth]). Both read the same on-device Health
/// Connect store via the `health` plugin; the [provider] argument only
/// stamps which slot the resulting [WearableSource] / aggregate belongs
/// to. There is no OAuth token — [authenticate] requests on-device
/// permissions and returns a sentinel [OAuthTokenSet] so the existing
/// [WearableSyncService] persistence path still has a non-empty token to
/// store.
///
/// Field mapping (Android-only types; confirmed against health 13.3.1):
/// - steps ← [HealthDataType.STEPS]
/// - activeMinutes ← [HealthDataType.ACTIVITY_INTENSITY] (EXERCISE_TIME is iOS-only)
/// - hrvNightly ← [HealthDataType.HEART_RATE_VARIABILITY_RMSSD], tagged
///   [DailyWearableAggregate.hrvMeasurementType] = `"rmssd"` (SDNN does not
///   exist as an Android data type in this plugin)
/// - restingHeartRate ← [HealthDataType.RESTING_HEART_RATE]
/// - sleep stages ← SLEEP_DEEP / SLEEP_REM / SLEEP_LIGHT / SLEEP_ASLEEP /
///   SLEEP_AWAKE, with SLEEP_SESSION as a fallback for total duration
class HealthConnectAdapter implements WearableAdapter {
  /// Sentinel stored as the "access token" after Health Connect permissions
  /// are granted. Not a secret and not sent to any network API.
  static const String grantedToken = 'health_connect_granted';

  /// Android HRV statistic. The only Health Connect HRV type this plugin
  /// exposes; persisted on the aggregate so downstream consumers never
  /// confuse it with iOS SDNN.
  static const String hrvMeasurementType = 'rmssd';

  static const List<HealthDataType> readTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.ACTIVITY_INTENSITY,
  ];

  final WearableProvider _provider;
  final HealthConnectClient _client;
  final bool _isAndroid;

  HealthConnectAdapter({
    WearableProvider provider = WearableProvider.googleFit,
    HealthConnectClient? client,
    bool? isAndroid,
  })  : _provider = provider,
        _client = client ?? PluginHealthConnectClient(),
        _isAndroid = isAndroid ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  WearableProvider get provider => _provider;

  @override
  List<WearableScope> get supportedScopes => const [
        WearableScope.sleep,
        WearableScope.hrv,
        WearableScope.activity,
        WearableScope.heartRate,
      ];

  @override
  Future<OAuthTokenSet> authenticate() async {
    if (!_isAndroid) {
      throw WearableAuthException(
        'Health Connect is only available on Android',
        provider: provider.name,
      );
    }

    try {
      await _client.configure();
      if (!await _client.isAvailable()) {
        await _client.promptInstall();
        throw WearableAuthException(
          'Health Connect is not installed. Install it from the Play Store and try again.',
          provider: provider.name,
        );
      }

      final granted = await _client.requestAuthorization(readTypes);
      if (!granted) {
        throw WearableAuthException(
          'Health Connect permissions were not granted',
          provider: provider.name,
        );
      }

      await _client.requestExtendedReadAccess();
      return const OAuthTokenSet(accessToken: grantedToken);
    } on WearableAuthException {
      rethrow;
    } catch (e) {
      throw WearableAuthException(
        'Health Connect authorization failed: $e',
        provider: provider.name,
      );
    }
  }

  @override
  Future<DailyWearableAggregate?> fetchDaySummary(
      String accessToken, String date) async {
    final day = _parseDate(date);
    // Overnight sleep ending on [date] typically starts the previous
    // evening, so the query window opens at noon the day before.
    final start = day.subtract(const Duration(hours: 12));
    final end = day.add(const Duration(days: 1));

    try {
      await _client.configure();
      final points = await _client.read(
        types: readTypes,
        startTime: start,
        endTime: end,
      );
      return parseAggregate(
        date: date,
        points: points,
        dayStart: day,
        provider: provider,
      );
    } on WearableAuthException {
      rethrow;
    } catch (e) {
      throw WearableAuthException(
        'Health Connect read failed: $e',
        provider: provider.name,
      );
    }
  }

  @override
  Future<OAuthTokenSet> refreshToken(OAuthTokenSet existingToken) async {
    return existingToken;
  }

  static DateTime _parseDate(String date) {
    final parts = date.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _overlaps(HealthDataPoint p, DateTime start, DateTime end) =>
      p.dateFrom.isBefore(end) && p.dateTo.isAfter(start);

  static double? _numeric(HealthDataPoint p) {
    final v = p.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    if (v is ActivityIntensityHealthValue) return v.minutes;
    return null;
  }

  static double _sumType(
    Iterable<HealthDataPoint> points,
    HealthDataType type,
  ) {
    var sum = 0.0;
    for (final p in points) {
      if (p.type != type) continue;
      final n = _numeric(p);
      if (n != null) sum += n;
    }
    return sum;
  }

  /// Pure mapping of Health Connect data points onto [DailyWearableAggregate].
  /// Separated from the plugin call for testability.
  @visibleForTesting
  static DailyWearableAggregate? parseAggregate({
    required String date,
    required List<HealthDataPoint> points,
    DateTime? dayStart,
    WearableProvider provider = WearableProvider.googleFit,
  }) {
    final day = dayStart ?? _parseDate(date);
    final dayEnd = day.add(const Duration(days: 1));
    final overnightStart = day.subtract(const Duration(hours: 12));

    // Sleep is dated by the morning it ends (same convention as Fitbit /
    // Google Health API). Stages whose interval ends on [date] belong here.
    final sleepPoints = points.where(
      (p) =>
          (p.type == HealthDataType.SLEEP_DEEP ||
              p.type == HealthDataType.SLEEP_REM ||
              p.type == HealthDataType.SLEEP_LIGHT ||
              p.type == HealthDataType.SLEEP_ASLEEP ||
              p.type == HealthDataType.SLEEP_AWAKE ||
              p.type == HealthDataType.SLEEP_SESSION) &&
          _sameCalendarDay(p.dateTo, day),
    );

    final deep = _sumType(sleepPoints, HealthDataType.SLEEP_DEEP);
    final rem = _sumType(sleepPoints, HealthDataType.SLEEP_REM);
    final light = _sumType(sleepPoints, HealthDataType.SLEEP_LIGHT);
    final asleepUnknown = _sumType(sleepPoints, HealthDataType.SLEEP_ASLEEP);
    final sessionFallback = _sumType(sleepPoints, HealthDataType.SLEEP_SESSION);
    final awakeCount =
        sleepPoints.where((p) => p.type == HealthDataType.SLEEP_AWAKE).length;

    final stagedAsleep = deep + rem + light + asleepUnknown;
    int? totalSleepMinutes;
    double? deepSleepPercent;
    double? remSleepPercent;
    if (stagedAsleep > 0) {
      totalSleepMinutes = stagedAsleep.round();
      deepSleepPercent = deep / stagedAsleep * 100;
      remSleepPercent = rem / stagedAsleep * 100;
    } else if (sessionFallback > 0) {
      totalSleepMinutes = sessionFallback.round();
    }

    final int? awakenings = awakeCount > 0 ? awakeCount : null;

    final dayPoints = points.where((p) => _overlaps(p, day, dayEnd));

    final stepsSum = _sumType(dayPoints, HealthDataType.STEPS);
    final int? steps = stepsSum > 0 ? stepsSum.round() : null;

    final intensitySum = _sumType(dayPoints, HealthDataType.ACTIVITY_INTENSITY);
    final int? activeMinutes = intensitySum > 0 ? intensitySum.round() : null;

    final rhrValues = dayPoints
        .where((p) => p.type == HealthDataType.RESTING_HEART_RATE)
        .map(_numeric)
        .whereType<double>()
        .toList();
    final int? restingHeartRate =
        rhrValues.isEmpty ? null : rhrValues.last.round();

    // Nightly HRV: RMSSD samples from the previous evening through this
    // calendar day. Always tagged "rmssd" — SDNN is not an Android type.
    final hrvValues = points
        .where((p) =>
            p.type == HealthDataType.HEART_RATE_VARIABILITY_RMSSD &&
            _overlaps(p, overnightStart, dayEnd))
        .map(_numeric)
        .whereType<double>()
        .toList();
    final double? hrvNightly = hrvValues.isEmpty
        ? null
        : hrvValues.reduce((a, b) => a + b) / hrvValues.length;

    if (totalSleepMinutes == null &&
        steps == null &&
        restingHeartRate == null &&
        hrvNightly == null &&
        activeMinutes == null) {
      return null;
    }

    return DailyWearableAggregate(
      uid: '',
      date: date,
      provider: provider,
      totalSleepMinutes: totalSleepMinutes,
      deepSleepPercent: deepSleepPercent,
      remSleepPercent: remSleepPercent,
      awakenings: awakenings,
      hrvNightly: hrvNightly,
      hrvMeasurementType:
          hrvNightly == null ? null : HealthConnectAdapter.hrvMeasurementType,
      restingHeartRate: restingHeartRate,
      steps: steps,
      activeMinutes: activeMinutes,
      syncedAt: DateTime.now(),
    );
  }
}
