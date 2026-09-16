import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/oauth_token_set.dart';

/// Thrown when OAuth or wearable authentication fails.
class WearableAuthException implements Exception {
  final String message;
  final String? provider;

  WearableAuthException(this.message, {this.provider});

  @override
  String toString() => 'WearableAuthException: $message${provider != null ? ' ($provider)' : ''}';
}

abstract class WearableAdapter {
  WearableProvider get provider;
  List<WearableScope> get supportedScopes;

  /// Opens OAuth flow; returns a token set or throws [WearableAuthException].
  /// On-device / mock adapters return a sentinel [OAuthTokenSet] with no
  /// refresh token and no expiry.
  Future<OAuthTokenSet> authenticate();

  /// Fetches nightly summary for [date] using a valid access token.
  /// Returns null if not yet available.
  Future<DailyWearableAggregate?> fetchDaySummary(String accessToken, String date);

  /// Refreshes [existingToken] if the provider's flow supports it.
  /// Adapters with no real OAuth return [existingToken] unchanged.
  Future<OAuthTokenSet> refreshToken(OAuthTokenSet existingToken);
}
