import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/sync_audit_record.dart';

/// Firestore repository for wearable sources and daily aggregates.
///
/// Paths:
/// - wearableSources: users/{uid}/wearableSources/{provider.name}
/// - dailyAggregates: users/{uid}/dailyWearableAggregates/{date}
class WearableRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sourcesCol(String uid) =>
      _db.collection('users').doc(uid).collection('wearableSources');

  CollectionReference<Map<String, dynamic>> _aggregatesCol(String uid) =>
      _db.collection('users').doc(uid).collection('dailyWearableAggregates');

  Future<void> saveSource(WearableSource source) async {
    await _sourcesCol(source.uid)
        .doc(source.provider.name)
        .set(source.toFirestore(), SetOptions(merge: true));
  }

  Future<List<WearableSource>> listActiveSources(String uid) async {
    final snap = await _sourcesCol(uid).get();
    return snap.docs
        .map((doc) => WearableSource.fromFirestore(doc.data(), id: doc.id))
        .where((s) => s.isActive)
        .toList();
  }

  Future<WearableSource?> getSource(String uid, WearableProvider provider) async {
    final doc = await _sourcesCol(uid).doc(provider.name).get();
    if (!doc.exists || doc.data() == null) return null;
    return WearableSource.fromFirestore(doc.data()!, id: doc.id);
  }

  Future<void> upsertAggregate(DailyWearableAggregate agg) async {
    await _aggregatesCol(agg.uid)
        .doc(agg.date)
        .set(agg.toFirestore(), SetOptions(merge: true));
  }

  Future<DailyWearableAggregate?> getAggregate(String uid, String date) async {
    final doc = await _aggregatesCol(uid).doc(date).get();
    if (!doc.exists || doc.data() == null) return null;
    return DailyWearableAggregate.fromFirestore(doc.data()!);
  }

  Future<List<DailyWearableAggregate>> getAggregates(
    String uid, {
    required int days,
  }) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    final startDate = _formatDate(start);

    final snap = await _aggregatesCol(uid)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .orderBy('date', descending: true)
        .get();

    return snap.docs
        .map((doc) => DailyWearableAggregate.fromFirestore(doc.data()))
        .toList();
  }

  Future<void> disconnectProvider(String uid, WearableProvider provider) async {
    await _sourcesCol(uid).doc(provider.name).delete();
  }

  CollectionReference<Map<String, dynamic>> _syncAuditCol(String uid) =>
      _db.collection('users').doc(uid).collection('syncAuditLog');

  Future<void> saveSyncAudit(SyncAuditRecord record) async {
    final docId = record.ranAt.toIso8601String();
    await _syncAuditCol(record.uid).doc(docId).set(record.toFirestore());
  }

  Future<SyncAuditRecord?> getLatestSyncAudit(String uid) async {
    final snap = await _syncAuditCol(uid)
        .orderBy('ranAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return SyncAuditRecord.fromFirestore(snap.docs.first.data());
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
