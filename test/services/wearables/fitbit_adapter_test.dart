import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dhealth/models/oauth_token_set.dart';
import 'package:dhealth/services/wearables/fitbit_adapter.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

void main() {
  group('FitbitAdapter.parseAggregate (Google Health API shapes)', () {
    test('maps sleep stages, steps roll-up, resting HR, and HRV', () {
      final agg = FitbitAdapter.parseAggregate(
        date: '2026-09-01',
        sleepDataPoints: [
          {
            'sleep': {
              'interval': {
                'startTime': '2026-08-31T23:00:00Z',
                'endTime': '2026-09-01T07:00:00Z',
              },
              'stages': [
                {
                  'type': 'DEEP',
                  'startTime': '2026-08-31T23:00:00Z',
                  'endTime': '2026-09-01T00:20:00Z',
                },
                {
                  'type': 'REM',
                  'startTime': '2026-09-01T00:20:00Z',
                  'endTime': '2026-09-01T01:45:00Z',
                },
                {
                  'type': 'LIGHT',
                  'startTime': '2026-09-01T01:45:00Z',
                  'endTime': '2026-09-01T06:50:00Z',
                },
              ],
              'shortAwakenings': [
                {'startTime': '2026-09-01T02:00:00Z', 'endTime': '2026-09-01T02:05:00Z'},
                {'startTime': '2026-09-01T04:00:00Z', 'endTime': '2026-09-01T04:03:00Z'},
              ],
            },
          },
        ],
        stepsRollup: {
          'steps': {'countSum': 8500},
        },
        activeMinutesRollup: {
          'activeMinutes': {'minutesSum': 35},
        },
        restingHeartRateDataPoints: [
          {
            'dailyRestingHeartRate': {'bpm': 58},
          },
        ],
        hrvDataPoints: [
          {
            'dailyHeartRateVariability': {'rmssd': 42.5},
          },
        ],
      );

      expect(agg, isNotNull);
      expect(agg!.totalSleepMinutes, 80 + 85 + 305); // deep + rem + light
      expect(agg.deepSleepPercent, closeTo(80 / (80 + 85 + 305) * 100, 0.01));
      expect(agg.remSleepPercent, closeTo(85 / (80 + 85 + 305) * 100, 0.01));
      expect(agg.awakenings, 2);
      expect(agg.steps, 8500);
      expect(agg.activeMinutes, 35);
      expect(agg.restingHeartRate, 58);
      expect(agg.hrvNightly, 42.5);
      // No Google Health API equivalent found for either — must stay null.
      expect(agg.sleepScore, isNull);
      expect(agg.deviceStressScore, isNull);
    });

    test('picks the longest sleep session when multiple are returned (e.g. a nap)', () {
      final agg = FitbitAdapter.parseAggregate(
        date: '2026-09-01',
        sleepDataPoints: [
          {
            'sleep': {
              'interval': {
                'startTime': '2026-09-01T13:00:00Z',
                'endTime': '2026-09-01T13:30:00Z',
              },
              'stages': [
                {'type': 'LIGHT', 'startTime': '2026-09-01T13:00:00Z', 'endTime': '2026-09-01T13:30:00Z'},
              ],
            },
          },
          {
            'sleep': {
              'interval': {
                'startTime': '2026-08-31T23:00:00Z',
                'endTime': '2026-09-01T07:00:00Z',
              },
              'stages': [
                {'type': 'LIGHT', 'startTime': '2026-08-31T23:00:00Z', 'endTime': '2026-09-01T07:00:00Z'},
              ],
            },
          },
        ],
      );

      expect(agg, isNotNull);
      expect(agg!.totalSleepMinutes, 480); // the 8-hour overnight session, not the 30-min nap
    });

    test('falls back to interval duration when no stage detail is present', () {
      final agg = FitbitAdapter.parseAggregate(
        date: '2026-09-01',
        sleepDataPoints: [
          {
            'sleep': {
              'interval': {
                'startTime': '2026-08-31T23:00:00Z',
                'endTime': '2026-09-01T07:00:00Z',
              },
            },
          },
        ],
      );

      expect(agg, isNotNull);
      expect(agg!.totalSleepMinutes, 480);
      expect(agg.deepSleepPercent, isNull);
      expect(agg.awakenings, isNull);
    });

    test('returns null when nothing produced usable data', () {
      final agg = FitbitAdapter.parseAggregate(date: '2026-09-01');
      expect(agg, isNull);
    });

    test('tolerates an unrecognized rollup/value field shape without crashing', () {
      final agg = FitbitAdapter.parseAggregate(
        date: '2026-09-01',
        stepsRollup: {
          'steps': {'someUnexpectedKey': 8500},
        },
        restingHeartRateDataPoints: [
          {
            'dailyRestingHeartRate': {'someUnexpectedKey': 58},
          },
        ],
      );

      // Every guessed field name missed -> everything null -> no aggregate,
      // not a crash.
      expect(agg, isNull);
    });
  });

  group('FitbitAdapter.fetchDaySummary', () {
    test('parses a full set of successful Google Health API responses', () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/dataTypes/sleep/dataPoints')) {
          expect(request.url.queryParameters['filter'], contains('sleep.interval.end_time'));
          return http.Response(
            jsonEncode({
              'dataPoints': [
                {
                  'sleep': {
                    'interval': {
                      'startTime': '2026-08-31T23:00:00Z',
                      'endTime': '2026-09-01T07:00:00Z',
                    },
                    'stages': [
                      {'type': 'DEEP', 'startTime': '2026-08-31T23:00:00Z', 'endTime': '2026-09-01T00:00:00Z'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        if (path.contains('/dataTypes/steps/dataPoints:dailyRollUp')) {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['range'], isNotNull);
          return http.Response(
            jsonEncode({
              'rollupDataPoints': [
                {
                  'steps': {'countSum': 9000},
                },
              ],
            }),
            200,
          );
        }
        if (path.contains('/dataTypes/active-minutes/dataPoints:dailyRollUp')) {
          return http.Response(
            jsonEncode({
              'rollupDataPoints': [
                {
                  'activeMinutes': {'minutesSum': 30},
                },
              ],
            }),
            200,
          );
        }
        if (path.contains('/dataTypes/daily-resting-heart-rate/dataPoints')) {
          return http.Response(
            jsonEncode({
              'dataPoints': [
                {
                  'dailyRestingHeartRate': {'bpm': 60},
                },
              ],
            }),
            200,
          );
        }
        if (path.contains('/dataTypes/daily-heart-rate-variability/dataPoints')) {
          return http.Response(
            jsonEncode({
              'dataPoints': [
                {
                  'dailyHeartRateVariability': {'rmssd': 38.2},
                },
              ],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final adapter = FitbitAdapter(client: client);
      final agg = await adapter.fetchDaySummary('valid-token', '2026-09-01');

      expect(agg, isNotNull);
      expect(agg!.totalSleepMinutes, 60);
      expect(agg.steps, 9000);
      expect(agg.activeMinutes, 30);
      expect(agg.restingHeartRate, 60);
      expect(agg.hrvNightly, 38.2);
    });

    test('throws WearableAuthException on a 401 from any endpoint', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/dataTypes/sleep/dataPoints')) {
          return http.Response('unauthorized', 401);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final adapter = FitbitAdapter(client: client);
      expect(
        () => adapter.fetchDaySummary('expired-token', '2026-09-01'),
        throwsA(isA<WearableAuthException>()),
      );
    });

    test('returns null when Google Health API has no data yet for the date', () async {
      final client = MockClient((request) async => http.Response('', 404));

      final adapter = FitbitAdapter(client: client);
      final agg = await adapter.fetchDaySummary('valid-token', '2026-09-01');

      expect(agg, isNull);
    });
  });

  group('FitbitAdapter OAuth (Google endpoints)', () {
    test('refreshToken posts to oauth2.googleapis.com and keeps the existing '
        'refresh token when Google omits one from the response', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://oauth2.googleapis.com/token');
        final body = Uri.splitQueryString(request.body);
        expect(body['grant_type'], 'refresh_token');
        expect(body['refresh_token'], 'old-refresh-token');
        expect(body['client_secret'], isNull); // no secret configured in this test
        return http.Response(
          jsonEncode({
            'access_token': 'new-access-token',
            'expires_in': 3600,
            // no refresh_token in the response, matching Google's typical
            // non-rotating behavior
          }),
          200,
        );
      });

      final adapter =
          FitbitAdapter(client: client, clientId: 'test-client-id', clientSecret: '');
      final result = await adapter.refreshToken(
        const OAuthTokenSet(
          accessToken: 'old-access-token',
          refreshToken: 'old-refresh-token',
        ),
      );

      expect(result.accessToken, 'new-access-token');
      expect(result.refreshToken, 'old-refresh-token'); // fallback preserved
      expect(result.expiresAt, isNotNull);
    });

    test('includes client_secret in the token request when one is configured', () async {
      final client = MockClient((request) async {
        final body = Uri.splitQueryString(request.body);
        expect(body['client_secret'], 'test-secret');
        return http.Response(jsonEncode({'access_token': 'a', 'expires_in': 3600}), 200);
      });

      final adapter = FitbitAdapter(
        client: client,
        clientId: 'test-client-id',
        clientSecret: 'test-secret',
      );
      await adapter.refreshToken(
        const OAuthTokenSet(accessToken: 'old', refreshToken: 'refresh'),
      );
    });

    test('is a no-op when there is no refresh token to use', () async {
      final client = MockClient((request) async {
        fail('should not call the network without a refresh token');
      });

      final adapter = FitbitAdapter(client: client);
      const tokenSet = OAuthTokenSet(accessToken: 'access-only');
      final result = await adapter.refreshToken(tokenSet);

      expect(result, same(tokenSet));
    });

    test('throws WearableAuthException when the refresh token is rejected', () async {
      final client = MockClient((request) async => http.Response('', 400));

      final adapter =
          FitbitAdapter(client: client, clientId: 'test-client-id', clientSecret: '');
      expect(
        () => adapter.refreshToken(
          const OAuthTokenSet(accessToken: 'old', refreshToken: 'revoked-refresh-token'),
        ),
        throwsA(isA<WearableAuthException>()),
      );
    });

    test('authenticate() throws WearableAuthException when no client ID is configured', () async {
      final adapter = FitbitAdapter(clientId: '');
      expect(
        () => adapter.authenticate(),
        throwsA(isA<WearableAuthException>()),
      );
    });
  });
}
