import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/oauth_token_set.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';

/// Inert placeholder for a [WearableProvider] whose real adapter exists in
/// the codebase but is intentionally not wired up for this release (see
/// fitbit_adapter.dart's header comment for why Fitbit specifically is
/// parked). Every method fails immediately and explicitly rather than
/// attempting a network call with unconfigured credentials — there is
/// nothing to connect to, so nothing should look like a hung or
/// partially-working connection.
class DisabledWearableAdapter implements WearableAdapter {
  @override
  final WearableProvider provider;

  DisabledWearableAdapter(this.provider);

  @override
  List<WearableScope> get supportedScopes => const [];

  @override
  Future<OAuthTokenSet> authenticate() async {
    throw WearableAuthException(
      '${provider.name} is not available in this release',
      provider: provider.name,
    );
  }

  @override
  Future<DailyWearableAggregate?> fetchDaySummary(
      String accessToken, String date) async {
    throw WearableAuthException(
      '${provider.name} is not available in this release',
      provider: provider.name,
    );
  }

  @override
  Future<OAuthTokenSet> refreshToken(OAuthTokenSet existingToken) async {
    throw WearableAuthException(
      '${provider.name} is not available in this release',
      provider: provider.name,
    );
  }
}
