import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit record for wearable nightly sync. Stored at:
/// users/{uid}/syncAuditLog/{ranAt.toIso8601String()}
///
/// Never stores raw OAuth tokens.
class SyncAuditRecord {
  final String uid;
  final DateTime ranAt;
  final String date; // yyyy-MM-dd
  final int successCount;
  final int failureCount;
  final List<String> errors;
  final int durationMs;

  const SyncAuditRecord({
    required this.uid,
    required this.ranAt,
    required this.date,
    required this.successCount,
    required this.failureCount,
    required this.errors,
    required this.durationMs,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'ranAt': ranAt.toIso8601String(),
      'date': date,
      'successCount': successCount,
      'failureCount': failureCount,
      'errors': errors,
      'durationMs': durationMs,
    };
  }

  static SyncAuditRecord fromFirestore(Map<String, dynamic> data) {
    return SyncAuditRecord(
      uid: data['uid'] as String? ?? '',
      ranAt: _parseDateTime(data['ranAt']),
      date: data['date'] as String? ?? '',
      successCount: data['successCount'] as int? ?? 0,
      failureCount: data['failureCount'] as int? ?? 0,
      errors: (data['errors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      durationMs: data['durationMs'] as int? ?? 0,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
