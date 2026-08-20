import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/models/clinical_message.dart';
import 'package:dhealth/models/doctor_session.dart';
import 'package:dhealth/services/doctor_patient_link_service.dart';

/// Manages clinically-scoped messaging between doctor and patient.
///
/// Firestore structure:
/// - users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}/doctorSession/current
/// - users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}/clinicalMessages/{messageId}
class ClinicalMessagingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DoctorPatientLinkService _linkService = DoctorPatientLinkService();

  static String _sanitizeEmailForPath(String email) {
    return email.replaceAll('.', '_').replaceAll('@', '_at_');
  }

  /// Doctor records that they viewed patient data. Call when opening patient detail or downloading report.
  Future<void> recordDoctorView({
    required String patientId,
    required String doctorEmail,
    String dataScope = 'logs',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email?.toLowerCase() != doctorEmail.trim().toLowerCase()) {
      throw StateError('Only the doctor can record a view.');
    }

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: doctorEmail,
    );
    if (!hasAccess) {
      throw StateError('Doctor does not have access to this patient.');
    }

    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    final ref = _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized)
        .collection('doctorSession')
        .doc('current');

    await ref.set(DoctorSession(
      viewedAt: DateTime.now(),
      dataScope: dataScope,
      doctorEmail: doctorEmail.trim().toLowerCase(),
    ).toJson());
  }

  /// Get the last time the doctor viewed this patient's data.
  Future<DoctorSession?> getLastDoctorView({
    required String patientId,
    required String doctorEmail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    final doc = await _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized)
        .collection('doctorSession')
        .doc('current')
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return DoctorSession.fromJson(doc.data()!);
  }

  /// Send a message in the clinical thread.
  Future<void> sendMessage({
    required String patientId,
    required String doctorEmail,
    required String sender,
    required String content,
    String? dataRangeReviewed,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Must be signed in to send messages.');

    if (sender != 'patient' && sender != 'doctor') {
      throw ArgumentError('sender must be "patient" or "doctor"');
    }
    if (sender == 'patient' && user.uid != patientId) {
      throw StateError('Only the patient can send as patient.');
    }
    if (sender == 'doctor' && user.email?.toLowerCase() != doctorEmail.trim().toLowerCase()) {
      throw StateError('Only the doctor can send as doctor.');
    }

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: doctorEmail,
    );
    if (!hasAccess) {
      throw StateError('No active link between this patient and doctor.');
    }

    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    final col = _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized)
        .collection('clinicalMessages');

    final data = <String, dynamic>{
      'sender': sender,
      'content': content.trim(),
      'sentAt': FieldValue.serverTimestamp(),
      if (dataRangeReviewed != null && dataRangeReviewed.isNotEmpty) 'dataRangeReviewed': dataRangeReviewed,
    };

    await col.add(data);
  }

  /// Stream messages in the clinical thread, ordered by sentAt ascending.
  Stream<List<ClinicalMessage>> streamMessages({
    required String patientId,
    required String doctorEmail,
  }) {
    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    return _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized)
        .collection('clinicalMessages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final sentAt = data['sentAt'];
              return ClinicalMessage(
                id: doc.id,
                sender: data['sender'] as String? ?? 'patient',
                content: data['content'] as String? ?? '',
                sentAt: sentAt is Timestamp
                    ? sentAt.toDate()
                    : (sentAt != null ? DateTime.parse(sentAt as String) : DateTime.now()),
                dataRangeReviewed: data['dataRangeReviewed'] as String?,
              );
            }).toList());
  }
}
