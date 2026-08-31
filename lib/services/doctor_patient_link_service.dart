import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/models/doctor_patient_link.dart';

/// Manages patient–doctor links for read-only doctor portal access.
///
/// Firestore structure:
/// - `users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}` — source of
///   truth, owned and read/written by the patient.
///   Fields: doctorEmail, consentedAt, createdAt, status
/// - `doctorLinks/{sanitizedDoctorEmail}/patients/{patientId}` — a parallel,
///   doctor-queryable index of the same link, written whenever the patient
///   creates/revokes a link. This exists because a `collectionGroup` query
///   using `FieldPath.documentId()` requires a full document *path* (even
///   segment count), not a bare ID — so a doctor cannot query across all
///   patients' `sharedWithDoctors` subcollections that way. Querying this
///   top-level `doctorLinks/{sanitizedDoctorEmail}/patients` collection
///   directly (not as a collection group) has no such restriction, and the
///   security rule can check the parent doc ID against the caller's own
///   token email directly.
///   Fields: patientId, patientDisplayName, status, createdAt, consentedAt
class DoctorPatientLinkService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _sanitizeEmailForPath(String email) {
    return email.replaceAll('.', '_').replaceAll('@', '_at_');
  }

  /// Patient grants consent: create link so doctor can read their data.
  /// Requires authenticated patient. Writes both the source-of-truth link
  /// and the doctor-queryable index in a single batch.
  Future<void> createLink({
    required String patientId,
    String? patientDisplayName,
    required String doctorEmail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != patientId) {
      throw StateError('Only the patient can create a share link.');
    }

    final normalizedEmail = doctorEmail.trim().toLowerCase();
    final sanitized = _sanitizeEmailForPath(normalizedEmail);
    final now = DateTime.now();

    final linkRef = _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized);
    final indexRef = _db
        .collection('doctorLinks')
        .doc(sanitized)
        .collection('patients')
        .doc(patientId);

    final payload = {
      'doctorEmail': normalizedEmail,
      'patientDisplayName': patientDisplayName,
      'status': LinkStatus.active.name,
      'createdAt': now.toIso8601String(),
      'consentedAt': now.toIso8601String(),
    };
    final indexPayload = {
      ...payload,
      'patientId': patientId,
    };

    final batch = _db.batch();
    batch.set(linkRef, payload);
    batch.set(indexRef, indexPayload);
    await batch.commit();
  }

  /// Patient revokes access. Updates both the source-of-truth link and the
  /// doctor-queryable index.
  Future<void> revokeLink({
    required String patientId,
    required String doctorEmail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != patientId) {
      throw StateError('Only the patient can revoke a share link.');
    }

    final sanitized = _sanitizeEmailForPath(doctorEmail.trim().toLowerCase());
    final revokedAt = DateTime.now().toIso8601String();

    final linkRef = _db
        .collection('users')
        .doc(patientId)
        .collection('sharedWithDoctors')
        .doc(sanitized);
    final indexRef = _db
        .collection('doctorLinks')
        .doc(sanitized)
        .collection('patients')
        .doc(patientId);

    final updatePayload = {
      'status': LinkStatus.revoked.name,
      'revokedAt': revokedAt,
    };

    final batch = _db.batch();
    batch.update(linkRef, updatePayload);
    batch.set(indexRef, updatePayload, SetOptions(merge: true));
    await batch.commit();
  }

  /// Doctor: list all patients who have shared access with this doctor's
  /// email. Queries the `doctorLinks/{sanitizedDoctorEmail}/patients` index
  /// directly (a normal subcollection query, not a collectionGroup), which
  /// the security rule permits by checking the parent doc ID against the
  /// caller's own token email.
  Future<List<DoctorPatientLink>> getLinksForDoctor(String doctorEmail) async {
    final normalizedEmail = doctorEmail.trim().toLowerCase();
    final sanitized = _sanitizeEmailForPath(normalizedEmail);

    try {
      final snap = await _db
          .collection('doctorLinks')
          .doc(sanitized)
          .collection('patients')
          .where('status', isEqualTo: LinkStatus.active.name)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return DoctorPatientLink(
          id: doc.id,
          patientId: (data['patientId'] as String?) ?? doc.id,
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