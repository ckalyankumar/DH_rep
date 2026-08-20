import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearable_repository.dart';
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

  WearableSyncService({WearableRepository? repo})
      : _repo = repo ?? WearableRepository();

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

    var token = source.encryptedOauthToken;
    if (token.isEmpty) return null;

    final adapter = WearableAdapterFactory.get(provider);
    try {
      token = await adapter.refreshToken(token);
    } on WearableAuthException {
      return null;
    }

    final agg = await adapter.fetchDaySummary(token, date);
    if (agg == null) return null;

    final aggWithUid = agg.copyWith(uid: uid);
    await _repo.upsertAggregate(aggWithUid);

    await _repo.saveSource(source.copyWith(
      encryptedOauthToken: token,
      lastSyncedAt: DateTime.now(),
    ));

    return aggWithUid;
  }

  /// Connect a new provider: authenticate → save WearableSource.
  Future<void> connect(String uid, WearableProvider provider) async {
    final adapter = WearableAdapterFactory.get(provider);
    final token = await adapter.authenticate();

    final source = WearableSource(
      id: provider.name,
      uid: uid,
      provider: provider,
      scopes: adapter.supportedScopes,
      encryptedOauthToken: token,
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
