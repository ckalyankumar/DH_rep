import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/models/medication_exception_event.dart';
import 'package:uuid/uuid.dart';

class FirestoreMedicationExceptionService {
  final FirebaseFirestore _db;

  FirestoreMedicationExceptionService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String uid) {
    return _db.collection('users').doc(uid).collection('medicationExceptions');
  }

  Future<MedicationExceptionEvent?> addException({
    required MedicationExceptionType type,
    required DateTime logDate,
    String? note,
    String? condition,
    DateTime? occurredAt,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final event = MedicationExceptionEvent(
      id: const Uuid().v4(),
      uid: uid,
      type: type,
      occurredAt: occurredAt ?? DateTime.now(),
      logDate: logDate,
      note: note,
      condition: condition,
      createdAt: DateTime.now(),
    );

    await _col(uid).doc(event.id).set(event.toJson(), SetOptions(merge: true));
    return event;
  }

  Future<List<MedicationExceptionEvent>> getForLastDays({
    required int days,
    String? uidOverride,
  }) async {
    final uid = uidOverride ?? _uid;
    if (uid == null) return [];

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final snap = await _col(uid)
        .where('occurredAt', isGreaterThanOrEqualTo: cutoff.toIso8601String())
        .orderBy('occurredAt', descending: true)
        .get();

    return snap.docs.map((d) => MedicationExceptionEvent.fromJson(d.data())).toList();
  }
}

