import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/oauth_token_set.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/services/wearable_token_cipher.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';
import 'package:dhealth/services/wearables/wearable_adapter_factory.dart';

class SyncResult {
  final int successCount;
  final int failureCount;
  final List<String> errors;

  const SyncResult({
    required this.successCount,
    required this.failureCount,
    this.errors = const [],
  });
}

class WearableSyncService {
  final WearableRepository _repo;
  final WearableTokenCipher _cipher;

  WearableSyncService({WearableRepository? repo, WearableTokenCipher? cipher})
      : _repo = repo ?? WearableRepository(),
        _cipher = cipher ?? WearableTokenCipher();

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Sync yesterday's data for all active providers for [uid].
  Future<SyncResult> syncAll(String uid) async {
    final sources = await _repo.listActiveSources(uid);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final date = _formatDate(yesterday);

    var successCount = 0;
    var failureCount = 0;
    final errors = <String>[];

    for (final source in sources) {
      try {
        final agg = await syncDate(uid, source.provider, date);
        if (agg != null) {
          successCount++;
        }
      } catch (e) {
        failureCount++;
        errors.add('${source.provider.name}: $e');
        // Avoid logging stack traces with tokens
      }
    }

    return SyncResult(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
    );
  }

  /// Sync a specific date for a specific provider.
  Future<DailyWearableAggregate?> syncDate(
      String uid, WearableProvider provider, String date) async {
    final source = await _repo.getSource(uid, provider);
    if (source == null || !source.isActive) return null;
    if (source.encryptedOauthToken.isEmpty) return null;

    final accessToken = await _cipher.decryptOrNull(source.encryptedOauthToken);
    if (accessToken == null) {
      // Ciphertext doesn't decrypt under the current device key — either
      // corrupted, or (pre-encryption test data) never actually
      // encrypted. Treated identically to an expired/revoked token:
      // no crash, no attempt to use it, just "needs reconnect."
      return null;
    }
    final refreshTokenValue =
        await _cipher.decryptOrNull(source.encryptedRefreshToken) ?? '';

    var tokenSet = OAuthTokenSet(
      accessToken: accessToken,
      refreshToken: refreshTokenValue,
      expiresAt: source.tokenExpiresAt,
    );

    final adapter = WearableAdapterFactory.get(provider);
    if (tokenSet.isExpired) {
      try {
        tokenSet = await adapter.refreshToken(tokenSet);
      } on WearableAuthException {
        return null;
      }
    }

    final agg = await adapter.fetchDaySummary(tokenSet.accessToken, date);
    if (agg == null) return null;

    final aggWithUid = agg.copyWith(uid: uid);
    await _repo.upsertAggregate(aggWithUid);

    await _repo.saveSource(source.copyWith(
      encryptedOauthToken: await _cipher.encrypt(tokenSet.accessToken),
      encryptedRefreshToken: await _cipher.encrypt(tokenSet.refreshToken),
      tokenExpiresAt: tokenSet.expiresAt,
      lastSyncedAt: DateTime.now(),
    ));

    return aggWithUid;
  }

  /// Connect a new provider: authenticate → save WearableSource.
  Future<void> connect(String uid, WearableProvider provider) async {
    final adapter = WearableAdapterFactory.get(provider);
    final tokenSet = await adapter.authenticate();

    final source = WearableSource(
      id: provider.name,
      uid: uid,
      provider: provider,
      scopes: adapter.supportedScopes,
      encryptedOauthToken: await _cipher.encrypt(tokenSet.accessToken),
      encryptedRefreshToken: await _cipher.encrypt(tokenSet.refreshToken),
      tokenExpiresAt: tokenSet.expiresAt,
      lastSyncedAt: DateTime.now(),
      isActive: true,
      consentGrantedAt: DateTime.now(),
    );
    await _repo.saveSource(source);
  }

  /// Disconnect: remove provider link and token.
  Future<void> disconnect(String uid, WearableProvider provider) async {
    await _repo.disconnectProvider(uid, provider);
  }
}
