import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/models/flare_event.dart';

/// Path: users/{uid}/flareEvents/{eventId}
class FirestoreFlareEventService {
  final FirebaseFirestore _db;
  final String? _userId;

  FirestoreFlareEventService({FirebaseFirestore? firestore, String? userId})
      : _db = firestore ?? FirebaseFirestore.instance,
        _userId = userId;

  String? get _effectiveUserId => _userId ?? FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col {
    final uid = _effectiveUserId;
    if (uid == null) throw StateError('No userId for flare events');
    return _db.collection('users').doc(uid).collection('flareEvents');
  }

  static String eventIdForOnset(DateTime onsetDate, FlareEventSource source) {
    final d = DateTime(onsetDate.year, onsetDate.month, onsetDate.day);
    final day = d.toIso8601String().substring(0, 10);
    return 'flare_${day}_${source.jsonValue}';
  }

  Future<void> upsertEvent(FlareEvent event) async {
    if (_effectiveUserId == null) return;
    await _col.doc(event.id).set(event.toJson(), SetOptions(merge: true));
  }

  Future<List<FlareEvent>> getForLastDays({
    required int days,
  }) async {
    if (_effectiveUserId == null) return [];
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snap = await _col
        .where('onsetDate', isGreaterThanOrEqualTo: cutoff.toIso8601String())
        .orderBy('onsetDate', descending: true)
        .get();
    return snap.docs.map((d) => FlareEvent.fromJson(d.data())).toList();
  }

  Future<List<FlareEvent>> getForPatientLastDays({
    required String patientId,
    required int days,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snap = await _db
        .collection('users')
        .doc(patientId)
        .collection('flareEvents')
        .where('onsetDate', isGreaterThanOrEqualTo: cutoff.toIso8601String())
        .orderBy('onsetDate', descending: true)
        .get();
    return snap.docs.map((d) => FlareEvent.fromJson(d.data())).toList();
  }
}

