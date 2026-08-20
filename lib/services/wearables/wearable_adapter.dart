import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';

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

  /// Opens OAuth flow; returns access token or throws [WearableAuthException].
  Future<String> authenticate();

  /// Fetches nightly summary for [date]. Returns null if not yet available.
  Future<DailyWearableAggregate?> fetchDaySummary(String token, String date);

  /// Validates token is still valid; refreshes if possible.
  Future<String> refreshToken(String existingToken);
}
