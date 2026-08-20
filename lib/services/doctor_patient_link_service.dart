import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/debug_agent_log.dart';
import 'package:dhealth/models/doctor_patient_link.dart';

/// Manages patient–doctor links for read-only doctor portal access.
///
/// Firestore structure:
/// - `users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}` — patient grants access
///   Fields: doctorEmail, consentedAt, createdAt, status
///
/// For doctor query: collection group 'sharedWithDoctors' where doctorEmail == currentUser.email.
/// Alternatively we use a top-level `doctorPatientLinks` collection for simpler querying.
class DoctorPatientLinkService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _sanitizeEmailForPath(String email) {
    return email.replaceAll('.', '_').replaceAll('@', '_at_');
  }

  /// Patient grants consent: create link so doctor can read their data.
  /// Requires authenticated patient.
  Future<void> createLink({
    required String patientId,
    String? patientDisplayName,
    required String doctorEmail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != patientId) {
      throw StateError('Only the patient can create a share link.');
    }

    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    final ref = _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized);

    final now = DateTime.now();
    await ref.set({
      'doctorEmail': doctorEmail.trim().toLowerCase(),
      'patientDisplayName': patientDisplayName,
      'status': LinkStatus.active.name,
      'createdAt': now.toIso8601String(),
      'consentedAt': now.toIso8601String(),
    });
  }

  /// Patient revokes access.
  Future<void> revokeLink({
    required String patientId,
    required String doctorEmail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != patientId) {
      throw StateError('Only the patient can revoke a share link.');
    }

    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    final ref = _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized);

    await ref.update({
      'status': LinkStatus.revoked.name,
      'revokedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Doctor: list all patients who have shared access with this doctor's email.
  Future<List<DoctorPatientLink>> getLinksForDoctor(String doctorEmail) async {
    final normalizedEmail = doctorEmail.trim().toLowerCase();

    try {
      final snap = await _db
          .collectionGroup('sharedWithDoctors')
          .where('doctorEmail', isEqualTo: normalizedEmail)
          .where('status', isEqualTo: LinkStatus.active.name)
          .get();

      // #region agent log
      agentDebugLog(
        location: 'doctor_patient_link_service.dart:getLinksForDoctor',
        message: 'collection group query ok',
        hypothesisId: 'H3',
        data: {
          'docCount': snap.docs.length,
          'emailLen': normalizedEmail.length,
        },
      );
      // #endregion

      return snap.docs.map((doc) {
        final data = doc.data();
        final patientId = doc.reference.parent.parent?.id ?? '';
        return DoctorPatientLink(
          id: doc.id,
          patientId: patientId,
          patientDisplayName: data['patientDisplayName'] as String?,
          doctorEmail: data['doctorEmail'] as String? ?? doctorEmail,
          status:
              LinkStatus.values.byName(data['status'] as String? ?? 'active'),
          createdAt: data['createdAt'] != null
              ? DateTime.parse(data['createdAt'] as String)
              : DateTime.now(),
          consentedAt: data['consentedAt'] != null
              ? DateTime.parse(data['consentedAt'] as String)
              : DateTime.now(),
          revokedAt: data['revokedAt'] != null
              ? DateTime.parse(data['revokedAt'] as String)
              : null,
        );
      }).toList();
    } catch (e, st) {
      // #region agent log
      agentDebugLog(
        location: 'doctor_patient_link_service.dart:getLinksForDoctor',
        message: 'collection group query failed',
        hypothesisId: 'H3',
        data: {
          'errorType': e.runtimeType.toString(),
          'errorBrief': e.toString().length > 120
              ? e.toString().substring(0, 120)
              : e.toString(),
        },
      );
      // #endregion
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Patient: list doctors they have shared with.
  Future<List<DoctorPatientLink>> getLinksForPatient(String patientId) async {
    final snap = await _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .where('status', isEqualTo: LinkStatus.active.name)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return DoctorPatientLink(
        id: doc.id,
        patientId: patientId,
        patientDisplayName: data['patientDisplayName'] as String?,
        doctorEmail: data['doctorEmail'] as String? ?? '',
        status: LinkStatus.values.byName(data['status'] as String? ?? 'active'),
        createdAt: data['createdAt'] != null
            ? DateTime.parse(data['createdAt'] as String)
            : DateTime.now(),
        consentedAt: data['consentedAt'] != null
            ? DateTime.parse(data['consentedAt'] as String)
            : DateTime.now(),
        revokedAt: data['revokedAt'] != null
            ? DateTime.parse(data['revokedAt'] as String)
            : null,
      );
    }).toList();
  }

  /// Check if doctor has active access to patient's data.
  Future<bool> hasAccess({
    required String patientId,
    required String doctorEmail,
  }) async {
    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    final doc = await _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized)
        .get();

    if (!doc.exists) return false;
    return doc.data()?['status'] == LinkStatus.active.name;
  }
}
