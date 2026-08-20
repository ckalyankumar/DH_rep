import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/models/flare_candidate.dart';

/// Path: users/{uid}/flareCandidates/{candidateId}
class FirestoreFlareCandidateService {
  final FirebaseFirestore _db;
  final String? _userId;

  FirestoreFlareCandidateService({FirebaseFirestore? firestore, String? userId})
      : _db = firestore ?? FirebaseFirestore.instance,
        _userId = userId;

  String? get _effectiveUserId => _userId ?? FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col {
    final uid = _effectiveUserId;
    if (uid == null) throw StateError('No userId for flare candidates');
    return _db.collection('users').doc(uid).collection('flareCandidates');
  }

  static String candidateIdForWindowStart(DateTime windowStartDate) {
    final d = DateTime(windowStartDate.year, windowStartDate.month, windowStartDate.day);
    return 'cand_${d.toIso8601String().substring(0, 10)}';
  }

  Future<void> upsertCandidate(FlareCandidate candidate) async {
    if (_effectiveUserId == null) return;
    await _col.doc(candidate.id).set(candidate.toJson(), SetOptions(merge: true));
  }

  Future<FlareCandidate?> getById(String id) async {
    if (_effectiveUserId == null) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return FlareCandidate.fromJson(data);
  }

  Future<FlareCandidate?> getLatestUndecided() async {
    if (_effectiveUserId == null) return null;
    final snap = await _col
        .orderBy('detectedAt', descending: true)
        .limit(20)
        .get();

    for (final doc in snap.docs) {
      final c = FlareCandidate.fromJson(doc.data());
      final isDecided = c.response != null || c.patientDismissed;
      if (!isDecided) return c;
    }
    return null;
  }
}

