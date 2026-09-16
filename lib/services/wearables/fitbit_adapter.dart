import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/oauth_token_set.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

/// ─────────────────────────────────────────────────────────────────────
/// STATUS: PARKED — built and tested, intentionally not activated.
/// ─────────────────────────────────────────────────────────────────────
/// This adapter is complete and covered by
/// test/services/wearables/fitbit_adapter_test.dart (all passing against
/// mocked Google Health API responses), but WearableAdapterFactory does
/// NOT route WearableProvider.fitbit here — it routes to
/// DisabledWearableAdapter instead. Nothing in the app will call this
/// class today.
///
/// Why: all Google Health API scopes are classified "Restricted," which
/// requires passing Google's recurring third-party CASA security audit
/// ($500–4,500/yr, plus engineering prep time, plus annual
/// recertification) before real users can authorize beyond a small
/// test-user list. That recurring cost isn't justified for a
/// bootstrapped, pre-revenue app with no committed Fitbit-specific
/// demand yet — Health Connect (Android) and HealthKit (iOS) cover
/// wearable sync for the large majority of users at zero compliance
/// cost, so Fitbit is deprioritized, not required for launch.
///
/// This code is reusable, not throwaway: revisit activating it (flip the
/// factory routing back to FitbitAdapter, fill in the Google Cloud OAuth
/// credentials, complete the CASA review) if a pilot partner's patient
/// population turns out to be Fitbit-heavy, or if the CASA cost becomes
/// justified once the app has scale/revenue. See the conversation this
/// was built in for the full research trail (Google Health API auth
/// flow, data model, and the several explicitly-flagged unverified
/// field-name guesses inside parseAggregate() below) before reactivating
/// — some of those should be re-checked against a live API response
/// rather than assumed still correct.
/// ─────────────────────────────────────────────────────────────────────
///
/// Backs the UI's "Fitbit" connection slot (WearableProvider.fitbit) via
/// the Google Health API (developers.google.com/health), which is
/// replacing Fitbit's own Web API — Google is retiring the legacy
/// fitbit.com / api.fitbit.com endpoints in September 2026. All Fitbit
/// (and Pixel Watch) data now flows through Google OAuth 2.0 and
/// health.googleapis.com instead of Fitbit's own developer platform.
/// Existing Fitbit OAuth tokens do not carry over — this is a full
/// re-consent, not a token migration.
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

  // Google's standard OAuth 2.0 endpoints (not Health-API-specific — these
  // are Google's universal identity endpoints).
  static const String authorizationUrl =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _apiBase = 'https://health.googleapis.com/v4';

  // All Google Health API scopes are classified "Restricted" by Google and
  // require a completed privacy/security (CASA) review before production
  // access. These exact scope strings are the best-confirmed ones from
  // Google's docs/codelab example — verify against the Data Access page
  // for your own OAuth consent screen before shipping; Google did not
  // publish an exhaustive scope-to-data-type table anywhere accessible
  // during this build.
  static const String _scopes =
      'https://www.googleapis.com/auth/googlehealth.sleep.readonly '
      'https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly '
      'https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly';

  final http.Client _client;
  final String? _clientIdOverride;
  final String? _clientSecretOverride;
  final String? _redirectUriOverride;

  /// Overrides exist for tests, so unit tests don't need `dotenv.load()`
  /// to have run. Production code always uses the default (reads .env).
  FitbitAdapter({
    http.Client? client,
    String? clientId,
    String? clientSecret,
    String? redirectUri,
  })  : _client = client ?? http.Client(),
        _clientIdOverride = clientId,
        _clientSecretOverride = clientSecret,
        _redirectUriOverride = redirectUri;

  String get _clientId =>
      _clientIdOverride ?? dotenv.env['GOOGLE_HEALTH_CLIENT_ID'] ?? '';

  // Optional: some Google installed-app OAuth client types issue a secret
  // even for a PKCE flow. Google's own docs describe this value as "not
  // treated as a secret" for installed apps — include it if present, omit
  // it otherwise, rather than assume either way.
  String get _clientSecret =>
      _clientSecretOverride ?? dotenv.env['GOOGLE_HEALTH_CLIENT_SECRET'] ?? '';

  String get _redirectUri =>
      _redirectUriOverride ??
      dotenv.env['GOOGLE_HEALTH_REDIRECT_URI'] ??
      'dhealth://oauth-callback/fitbit';

  String get _callbackScheme => Uri.parse(_redirectUri).scheme;

  @override
  Future<OAuthTokenSet> authenticate() async {
    if (_clientId.isEmpty) {
      throw WearableAuthException(
        'GOOGLE_HEALTH_CLIENT_ID is not configured in .env',
        provider: provider.name,
      );
    }

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _codeChallengeFor(codeVerifier);

    final authUri = Uri.parse(authorizationUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': _scopes,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      // access_type=offline + prompt=consent: without both, Google either
      // never returns a refresh_token, or only returns one on the user's
      // very first-ever consent. This is a real, documented Google OAuth
      // behavior, distinct from Fitbit's flow (which rotated a refresh
      // token on every use).
      'access_type': 'offline',
      'prompt': 'consent',
    });

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: _callbackScheme,
      );
    } catch (e) {
      throw WearableAuthException(
        'Google authorization was cancelled or failed: $e',
        provider: provider.name,
      );
    }

    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) {
      throw WearableAuthException(
        'Google did not return an authorization code',
        provider: provider.name,
      );
    }

    return _exchangeCodeForToken(code, codeVerifier);
  }

  @override
  Future<DailyWearableAggregate?> fetchDaySummary(
      String accessToken, String date) async {
    final dayStart = DateTime.parse('${date}T00:00:00Z');
    final dayEnd = dayStart.add(const Duration(days: 1));

    final responses = await Future.wait([
      _listDataPoints(accessToken, 'sleep',
          _intervalFilter('sleep', 'end_time', dayStart, dayEnd)),
      _dailyRollUp(accessToken, 'steps', dayStart),
      _dailyRollUp(accessToken, 'active-minutes', dayStart),
      _listDataPoints(
          accessToken,
          'daily-resting-heart-rate',
          _intervalFilter(
              'dailyRestingHeartRate', 'start_time', dayStart, dayEnd)),
      _listDataPoints(
          accessToken,
          'daily-heart-rate-variability',
          _intervalFilter(
              'dailyHeartRateVariability', 'start_time', dayStart, dayEnd)),
    ]);

    if (responses.any((r) => r.statusCode == 401 || r.statusCode == 403)) {
      throw WearableAuthException(
        'Google Health API rejected the access token',
        provider: provider.name,
      );
    }

    return parseAggregate(
      date: date,
      sleepDataPoints: _decodeListOrNull(responses[0], 'dataPoints'),
      stepsRollup: _decodeRollupOrNull(responses[1]),
      activeMinutesRollup: _decodeRollupOrNull(responses[2]),
      restingHeartRateDataPoints: _decodeListOrNull(responses[3], 'dataPoints'),
      hrvDataPoints: _decodeListOrNull(responses[4], 'dataPoints'),
    );
  }

  @override
  Future<OAuthTokenSet> refreshToken(OAuthTokenSet existingToken) async {
    if (existingToken.refreshToken.isEmpty) return existingToken;
    if (_clientId.isEmpty) {
      throw WearableAuthException(
        'GOOGLE_HEALTH_CLIENT_ID is not configured in .env',
        provider: provider.name,
      );
    }

    final response = await _client.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': existingToken.refreshToken,
      },
    );

    if (response.statusCode == 400 || response.statusCode == 401) {
      throw WearableAuthException(
        'Google refresh token was rejected',
        provider: provider.name,
      );
    }
    if (response.statusCode != 200) {
      throw WearableAuthException(
        'Google token refresh failed (${response.statusCode})',
        provider: provider.name,
      );
    }

    // Google does not rotate the refresh token on every use (unlike
    // Fitbit, which issued a new one on every refresh) — a refresh
    // response commonly omits refresh_token entirely, meaning "keep using
    // the one you already have."
    return _tokenSetFromResponse(response,
        fallbackRefreshToken: existingToken.refreshToken);
  }

  Future<OAuthTokenSet> _exchangeCodeForToken(
      String code, String codeVerifier) async {
    final response = await _client.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        if (_clientSecret.isNotEmpty) 'client_secret': _clientSecret,
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': _redirectUri,
      },
    );

    if (response.statusCode != 200) {
      throw WearableAuthException(
        'Google token exchange failed (${response.statusCode})',
        provider: provider.name,
      );
    }

    return _tokenSetFromResponse(response);
  }

  OAuthTokenSet _tokenSetFromResponse(http.Response response,
      {String fallbackRefreshToken = ''}) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresInSeconds = body['expires_in'] as int?;
    return OAuthTokenSet(
      accessToken: body['access_token'] as String? ?? '',
      refreshToken: body['refresh_token'] as String? ?? fallbackRefreshToken,
      expiresAt: expiresInSeconds != null
          ? DateTime.now().add(Duration(seconds: expiresInSeconds))
          : null,
    );
  }

  Future<http.Response> _listDataPoints(
      String accessToken, String dataType, String filter) {
    final uri = Uri.parse('$_apiBase/users/me/dataTypes/$dataType/dataPoints')
        .replace(queryParameters: {'filter': filter});
    return _client.get(uri, headers: {'Authorization': 'Bearer $accessToken'});
  }

  Future<http.Response> _dailyRollUp(
      String accessToken, String dataType, DateTime day) {
    final uri = Uri.parse(
        '$_apiBase/users/me/dataTypes/$dataType/dataPoints:dailyRollUp');
    final nextDay =
        DateTime(day.year, day.month, day.day).add(const Duration(days: 1));
    final body = jsonEncode({
      'range': {
        'start': {'year': day.year, 'month': day.month, 'day': day.day},
        'end': {
          'year': nextDay.year,
          'month': nextDay.month,
          'day': nextDay.day
        },
      },
      'windowSizeDays': 1,
    });
    return _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );
  }

  // Design choice, not confirmed against a real response: sleep is
  // filtered by which calendar day the session ENDS (Fitbit's own
  // convention — "last night's sleep" is dated by the morning it ends),
  // not when it starts. A session starting 11pm and ending 7am is
  // attributed to the end date. Daily vitals are filtered by start_time
  // since they're already single-day-scoped records, not overnight spans.
  static String _intervalFilter(
      String fieldName, String timeField, DateTime start, DateTime end) {
    return '$fieldName.interval.$timeField >= "${_rfc3339(start)}" AND '
        '$fieldName.interval.$timeField < "${_rfc3339(end)}"';
  }

  static String _rfc3339(DateTime dt) {
    final u = dt.toUtc();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${p2(u.month)}-${p2(u.day)}'
        'T${p2(u.hour)}:${p2(u.minute)}:${p2(u.second)}Z';
  }

  static Map<String, dynamic>? _decodeBodyOrNull(http.Response response) {
    if (response.statusCode != 200) return null;
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic>? _decodeListOrNull(http.Response response, String key) {
    final body = _decodeBodyOrNull(response);
    return body?[key] as List<dynamic>?;
  }

  static Map<String, dynamic>? _decodeRollupOrNull(http.Response response) {
    final body = _decodeBodyOrNull(response);
    final points = body?['rollupDataPoints'] as List<dynamic>?;
    if (points == null || points.isEmpty) return null;
    return points.first as Map<String, dynamic>;
  }

  static String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  static String _codeChallengeFor(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Pure parsing of Google Health API responses into the shared
  /// aggregate shape — separated from network calls for testability.
  /// Sleep and steps response shapes are confirmed against Google's own
  /// reference docs; resting heart rate, HRV, and active-minutes use
  /// best-guess field names (flagged inline below) since Google's docs
  /// named those data types but never showed a concrete JSON example for
  /// any of them at the time this was written. A wrong guess yields null
  /// for that one field, not a crash or wrong data — worth confirming
  /// against a real response once you have console access.
  @visibleForTesting
  static DailyWearableAggregate? parseAggregate({
    required String date,
    List<dynamic>? sleepDataPoints,
    Map<String, dynamic>? stepsRollup,
    Map<String, dynamic>? activeMinutesRollup,
    List<dynamic>? restingHeartRateDataPoints,
    List<dynamic>? hrvDataPoints,
  }) {
    int? totalSleepMinutes;
    double? deepSleepPercent;
    double? remSleepPercent;
    int? awakenings;

    if (sleepDataPoints != null && sleepDataPoints.isNotEmpty) {
      // Multiple sessions (e.g. a nap) can match the date filter — take
      // the longest as "main sleep," matching Fitbit's own convention.
      Map<String, dynamic>? mainSleep;
      var longestMinutes = -1;
      for (final entry in sleepDataPoints) {
        final sleep =
            (entry as Map<String, dynamic>)['sleep'] as Map<String, dynamic>?;
        final interval = sleep?['interval'] as Map<String, dynamic>?;
        final start = interval?['startTime'] as String?;
        final end = interval?['endTime'] as String?;
        if (sleep == null || start == null || end == null) continue;
        final minutes =
            DateTime.parse(end).difference(DateTime.parse(start)).inMinutes;
        if (minutes > longestMinutes) {
          longestMinutes = minutes;
          mainSleep = sleep;
        }
      }

      if (mainSleep != null) {
        final stages = mainSleep['stages'] as List<dynamic>?;
        if (stages != null && stages.isNotEmpty) {
          int stageMinutes(String type) {
            var sum = 0;
            for (final s in stages) {
              final stage = s as Map<String, dynamic>;
              if (stage['type'] != type) continue;
              final start = stage['startTime'] as String?;
              final end = stage['endTime'] as String?;
              if (start == null || end == null) continue;
              sum += DateTime.parse(end)
                  .difference(DateTime.parse(start))
                  .inMinutes;
            }
            return sum;
          }

          final deepMinutes = stageMinutes('DEEP');
          final remMinutes = stageMinutes('REM');
          final lightMinutes = stageMinutes('LIGHT');
          final asleepMinutes = deepMinutes + remMinutes + lightMinutes;

          if (asleepMinutes > 0) {
            totalSleepMinutes = asleepMinutes;
            deepSleepPercent = deepMinutes / asleepMinutes * 100;
            remSleepPercent = remMinutes / asleepMinutes * 100;
          }
        } else if (longestMinutes > 0) {
          totalSleepMinutes = longestMinutes;
        }

        final shortAwakenings = mainSleep['shortAwakenings'] as List<dynamic>?;
        awakenings = shortAwakenings?.length;
      }
    }

    // Confirmed shape: dailyRollUp response { steps: { countSum: N } }.
    // Checking a secondary "count_sum" key too since one Google doc
    // excerpt rendered it snake_case while the API otherwise uses
    // camelCase JSON.
    final steps =
        _firstInt(stepsRollup?['steps'], ['countSum', 'count_sum']);

    // UNCONFIRMED: "active-minutes" dailyRollUp response field name.
    // Google's docs named this data type but never showed a JSON example
    // for it — trying a few plausible keys rather than guessing one.
    final activeMinutes = _firstInt(
        activeMinutesRollup?['activeMinutes'],
        ['minutesSum', 'sum', 'value', 'minutes']);

    // UNCONFIRMED: "daily-resting-heart-rate" list response field names.
    final int? restingHeartRate;
    if (restingHeartRateDataPoints != null &&
        restingHeartRateDataPoints.isNotEmpty) {
      final value = (restingHeartRateDataPoints.first
          as Map<String, dynamic>)['dailyRestingHeartRate'] as Map<String, dynamic>?;
      restingHeartRate = _firstInt(value, ['bpm', 'value', 'beatsPerMinute']);
    } else {
      restingHeartRate = null;
    }

    // UNCONFIRMED: "daily-heart-rate-variability" list response field
    // names. Google's vitals doc confirms the metric is RMSSD (not
    // SDNN) but shows no JSON example — trying "rmssd" first.
    double? hrvNightly;
    if (hrvDataPoints != null && hrvDataPoints.isNotEmpty) {
      final value = (hrvDataPoints.first
          as Map<String, dynamic>)['dailyHeartRateVariability'] as Map<String, dynamic>?;
      final raw = value?['rmssd'] ?? value?['rmssdMillis'] ?? value?['value'];
      if (raw is num) hrvNightly = raw.toDouble();
    }

    // sleepScore intentionally omitted: no Google Health API equivalent
    // found (Fitbit's public API never exposed it either).
    // deviceStressScore intentionally omitted: not wired in without
    // explicit sign-off. `stress` stays null downstream in
    // WearableCheckinPrefillService, same as every non-Garmin provider.
    if (totalSleepMinutes == null &&
        steps == null &&
        restingHeartRate == null &&
        hrvNightly == null) {
      return null;
    }

    return DailyWearableAggregate(
      uid: '',
      date: date,
      provider: WearableProvider.fitbit,
      totalSleepMinutes: totalSleepMinutes,
      deepSleepPercent: deepSleepPercent,
      remSleepPercent: remSleepPercent,
      awakenings: awakenings,
      hrvNightly: hrvNightly,
      restingHeartRate: restingHeartRate,
      steps: steps,
      activeMinutes: activeMinutes,
      syncedAt: DateTime.now(),
    );
  }

  static int? _firstInt(dynamic map, List<String> candidateKeys) {
    if (map is! Map<String, dynamic>) return null;
    for (final key in candidateKeys) {
      final v = map[key];
      if (v is num) return v.toInt();
    }
    return null;
  }
}
