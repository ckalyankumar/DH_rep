import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';

import 'package:dhealth/models/sync_audit_record.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/services/wearable_sync_service.dart';
import 'package:dhealth/services/wearable_sync_prefs.dart';

import 'package:dhealth/firebase_options.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'wearableNightlySync') {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {
        // Firebase may already be initialized
      }

      final uid = await WearableSyncPrefs.getUid();
      if (uid == null || uid.isEmpty) {
        return true; // No user, nothing to sync; return true to avoid retries
      }

      final stopwatch = Stopwatch()..start();
      try {
        final repo = WearableRepository();
        final syncService = WearableSyncService(repo: repo);
        final result = await syncService.syncAll(uid);
        stopwatch.stop();

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final date =
            '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

        final record = SyncAuditRecord(
          uid: uid,
          ranAt: DateTime.now(),
          date: date,
          successCount: result.successCount,
          failureCount: result.failureCount,
          errors: result.errors,
          durationMs: stopwatch.elapsedMilliseconds,
        );
        await repo.saveSyncAudit(record);
        return true;
      } catch (e) {
        stopwatch.stop();
        try {
          final repo = WearableRepository();
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          final date =
              '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
          await repo.saveSyncAudit(SyncAuditRecord(
            uid: uid,
            ranAt: DateTime.now(),
            date: date,
            successCount: 0,
            failureCount: 1,
            errors: ['Sync failed: ${e.toString()}'],
            durationMs: stopwatch.elapsedMilliseconds,
          ));
        } catch (_) {
          // Best-effort audit write; do not crash
        }
        return true; // Return true to avoid retries when API unavailable
      }
    }
    return true;
  });
}
