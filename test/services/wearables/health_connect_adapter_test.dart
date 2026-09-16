import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/wearables/health_connect_adapter.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

HealthDataPoint _point({
  required HealthDataType type,
  required DateTime from,
  required DateTime to,
  num? numeric,
  HealthValue? value,
}) {
  return HealthDataPoint(
    uuid: '${type.name}-${from.toIso8601String()}',
    value: value ?? NumericHealthValue(numericValue: numeric ?? 0),
    type: type,
    unit: dataTypeToUnit[type] ?? HealthDataUnit.UNKNOWN_UNIT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'test',
    sourceId: 'test',
    sourceName: 'test',
  );
}

class FakeHealthConnectClient implements HealthConnectClient {
  bool configureCalled = false;
  bool available;
  bool grantAuthorization;
  bool promptInstallCalled = false;
  List<HealthDataPoint> points;

  FakeHealthConnectClient({
    this.available = true,
    this.grantAuthorization = true,
    List<HealthDataPoint>? points,
  }) : points = points ?? const [];

  @override
  Future<void> configure() async {
    configureCalled = true;
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> promptInstall() async {
    promptInstallCalled = true;
  }

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types) async =>
      grantAuthorization;

  @override
  Future<void> requestExtendedReadAccess() async {}

  @override
  Future<List<HealthDataPoint>> read({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
  }) async =>
      points;
}

void main() {
  final day = DateTime(2026, 9, 1);

  group('HealthConnectAdapter.parseAggregate', () {
    test('maps sleep stages, ACTIVITY_INTENSITY, RMSSD HRV, steps, and RHR',
        () {
      final agg = HealthConnectAdapter.parseAggregate(
        date: '2026-09-01',
        dayStart: day,
        points: [
          _point(
            type: HealthDataType.SLEEP_DEEP,
            from: DateTime(2026, 8, 31, 23, 0),
            to: DateTime(2026, 9, 1, 0, 20),
          ),
          _point(
            type: HealthDataType.SLEEP_REM,
            from: DateTime(2026, 9, 1, 0, 20),
            to: DateTime(2026, 9, 1, 1, 45),
          ),
          _point(
            type: HealthDataType.SLEEP_LIGHT,
            from: DateTime(2026, 9, 1, 1, 45),
            to: DateTime(2026, 9, 1, 6, 50),
          ),
          _point(
            type: HealthDataType.SLEEP_AWAKE,
            from: DateTime(2026, 9, 1, 2, 0),
            to: DateTime(2026, 9, 1, 2, 5),
          ),
          _point(
            type: HealthDataType.SLEEP_AWAKE,
            from: DateTime(2026, 9, 1, 4, 0),
            to: DateTime(2026, 9, 1, 4, 3),
          ),
          _point(
            type: HealthDataType.STEPS,
            from: DateTime(2026, 9, 1, 8),
            to: DateTime(2026, 9, 1, 9),
            numeric: 4000,
          ),
          _point(
            type: HealthDataType.STEPS,
            from: DateTime(2026, 9, 1, 12),
            to: DateTime(2026, 9, 1, 13),
            numeric: 4500,
          ),
          _point(
            type: HealthDataType.ACTIVITY_INTENSITY,
            from: DateTime(2026, 9, 1, 7),
            to: DateTime(2026, 9, 1, 7, 20),
            value: ActivityIntensityHealthValue(
              intensityLevel: ActivityIntensityLevel.moderate,
              minutes: 20,
            ),
          ),
          _point(
            type: HealthDataType.ACTIVITY_INTENSITY,
            from: DateTime(2026, 9, 1, 18),
            to: DateTime(2026, 9, 1, 18, 15),
            value: ActivityIntensityHealthValue(
              intensityLevel: ActivityIntensityLevel.vigorous,
              minutes: 15,
            ),
          ),
          _point(
            type: HealthDataType.RESTING_HEART_RATE,
            from: DateTime(2026, 9, 1, 6),
            to: DateTime(2026, 9, 1, 6),
            numeric: 58,
          ),
          _point(
            type: HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
            from: DateTime(2026, 9, 1, 3),
            to: DateTime(2026, 9, 1, 3),
            numeric: 40,
          ),
          _point(
            type: HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
            from: DateTime(2026, 9, 1, 5),
            to: DateTime(2026, 9, 1, 5),
            numeric: 50,
          ),
        ],
      );

      expect(agg, isNotNull);
      // SLEEP_* points convert dateTo-dateFrom to minutes in HealthDataPoint.
      expect(agg!.totalSleepMinutes, 80 + 85 + 305);
      expect(agg.deepSleepPercent, closeTo(80 / (80 + 85 + 305) * 100, 0.01));
      expect(agg.remSleepPercent, closeTo(85 / (80 + 85 + 305) * 100, 0.01));
      expect(agg.awakenings, 2);
      expect(agg.steps, 8500);
      expect(agg.activeMinutes, 35);
      expect(agg.restingHeartRate, 58);
      expect(agg.hrvNightly, 45);
      expect(agg.hrvMeasurementType, 'rmssd');
      expect(agg.sleepScore, isNull);
      expect(agg.deviceStressScore, isNull);
      expect(agg.provider, WearableProvider.googleFit);
    });

    test('falls back to SLEEP_SESSION minutes when no staged sleep is present',
        () {
      final agg = HealthConnectAdapter.parseAggregate(
        date: '2026-09-01',
        dayStart: day,
        points: [
          _point(
            type: HealthDataType.SLEEP_SESSION,
            from: DateTime(2026, 8, 31, 23),
            to: DateTime(2026, 9, 1, 7),
            numeric: 480,
          ),
        ],
      );

      expect(agg, isNotNull);
      expect(agg!.totalSleepMinutes, 480);
      expect(agg.deepSleepPercent, isNull);
      expect(agg.remSleepPercent, isNull);
    });

    test('returns null when no mapped fields are present', () {
      expect(
        HealthConnectAdapter.parseAggregate(
          date: '2026-09-01',
          dayStart: day,
          points: const [],
        ),
        isNull,
      );
    });

    test('ignores sleep that ended on a different calendar day', () {
      final agg = HealthConnectAdapter.parseAggregate(
        date: '2026-09-01',
        dayStart: day,
        points: [
          _point(
            type: HealthDataType.SLEEP_DEEP,
            from: DateTime(2026, 8, 30, 23),
            to: DateTime(2026, 8, 31, 6),
          ),
          _point(
            type: HealthDataType.STEPS,
            from: DateTime(2026, 9, 1, 8),
            to: DateTime(2026, 9, 1, 9),
            numeric: 1000,
          ),
        ],
      );

      expect(agg, isNotNull);
      expect(agg!.totalSleepMinutes, isNull);
      expect(agg.steps, 1000);
    });

    test('stamps WearableProvider.samsungHealth when that slot is requested', () {
      final agg = HealthConnectAdapter.parseAggregate(
        date: '2026-09-01',
        dayStart: day,
        provider: WearableProvider.samsungHealth,
        points: [
          _point(
            type: HealthDataType.STEPS,
            from: DateTime(2026, 9, 1, 8),
            to: DateTime(2026, 9, 1, 9),
            numeric: 1000,
          ),
        ],
      );

      expect(agg, isNotNull);
      expect(agg!.provider, WearableProvider.samsungHealth);
    });
  });

  group('HealthConnectAdapter.authenticate', () {
    test('returns a sentinel token when Health Connect grants permissions',
        () async {
      final adapter = HealthConnectAdapter(
        client: FakeHealthConnectClient(),
        isAndroid: true,
      );

      final token = await adapter.authenticate();
      expect(token.accessToken, HealthConnectAdapter.grantedToken);
      expect(token.refreshToken, isEmpty);
      expect(token.expiresAt, isNull);
    });

    test('throws on non-Android without touching the client', () async {
      final client = FakeHealthConnectClient();
      final adapter = HealthConnectAdapter(client: client, isAndroid: false);

      expect(
        () => adapter.authenticate(),
        throwsA(isA<WearableAuthException>()),
      );
      expect(client.configureCalled, isFalse);
    });

    test('prompts install and throws when Health Connect is missing', () async {
      final client = FakeHealthConnectClient(available: false);
      final adapter = HealthConnectAdapter(client: client, isAndroid: true);

      await expectLater(
        adapter.authenticate(),
        throwsA(isA<WearableAuthException>()),
      );
      expect(client.promptInstallCalled, isTrue);
    });

    test('throws when the user denies permissions', () async {
      final adapter = HealthConnectAdapter(
        client: FakeHealthConnectClient(grantAuthorization: false),
        isAndroid: true,
      );

      await expectLater(
        adapter.authenticate(),
        throwsA(isA<WearableAuthException>()),
      );
    });
  });
}
