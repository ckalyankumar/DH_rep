import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';
import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';

/// Portal data access via the **Firestore SDK + Firebase Auth ID token**.
///
/// This is the opposite of `tool/verify_clinical_evidence_reviews.dart`, which
/// uses Google OAuth / IAM against the REST API and therefore bypasses
/// `firestore.rules`. Every read and write here goes through
/// [FirebaseFirestore] so `clinicalReviewer` / `clinicalAdmin` rules apply.
class ClinicalReviewPortalService {
  ClinicalReviewPortalService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection(ClinicalReviewSchema.reviewsCollection);

  CollectionReference<Map<String, dynamic>> get _actions =>
      _db.collection(ClinicalReviewSchema.emergencyActionsCollection);

  Stream<String?> roleForUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      final profile = data?['profile'];
      if (profile is Map) {
        final raw = profile['role'];
        return raw is String ? raw : null;
      }
      return null;
    });
  }

  Stream<List<ClinicalEvidenceReviewDoc>> pendingReviews() {
    return _reviews
        .where(
          ClinicalReviewSchema.statusField,
          isEqualTo: ClinicalReviewSchema.statusPending,
        )
        .snapshots()
        .map((snap) {
      final rows = _reviewsFromSnapshot(snap);
      rows.sort(_bySubmittedDesc);
      return rows;
    });
  }

  Stream<List<ClinicalEvidenceReviewDoc>> allReviews() {
    return _reviews.snapshots().map((snap) {
      final rows = _reviewsFromSnapshot(snap);
      rows.sort(_bySubmittedDesc);
      return rows;
    });
  }

  Stream<ClinicalEvidenceReviewDoc?> review(String id) {
    return _reviews.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ClinicalEvidenceReviewDoc.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<EmergencyActionDoc>> emergencyActions() {
    return _actions.snapshots().map((snap) {
      final rows = [
        for (final doc in snap.docs)
          EmergencyActionDoc.fromMap(doc.id, doc.data()),
      ];
      rows.sort((a, b) {
        final at = b.actionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = a.actionAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return at.compareTo(bt);
      });
      return rows;
    });
  }

  Future<void> decideReview({
    required String reviewId,
    required String status,
    required String reviewedBy,
    String? reviewNotes,
    String? gradeLevel,
  }) {
    if (!ClinicalReviewSchema.reviewStatuses.contains(status) ||
        status == ClinicalReviewSchema.statusPending) {
      throw ArgumentError.value(status, 'status');
    }
    if (status == ClinicalReviewSchema.statusApproved &&
        (gradeLevel == null || gradeLevel.trim().isEmpty)) {
      throw ArgumentError('GRADE is required to approve');
    }
    if (status == ClinicalReviewSchema.statusApproved) {
      final notes = reviewNotes?.trim() ?? '';
      if (notes.length < ClinicalReviewSchema.approvalNotesMinLength) {
        throw ArgumentError(
          'Verification notes are required to approve '
          '(at least ${ClinicalReviewSchema.approvalNotesMinLength} characters)',
        );
      }
    }
    final data = <String, dynamic>{
      ClinicalReviewSchema.statusField: status,
      ClinicalReviewSchema.reviewedByField: reviewedBy,
      ClinicalReviewSchema.reviewedAtField: FieldValue.serverTimestamp(),
      ClinicalReviewSchema.reviewNotesField: reviewNotes,
    };
    if (status == ClinicalReviewSchema.statusApproved) {
      data[ClinicalReviewSchema.gradeLevelField] = gradeLevel!.trim();
    }
    return _reviews.doc(reviewId).update(data);
  }

  Future<void> saveReviewNotes({
    required String reviewId,
    required String reviewNotes,
  }) {
    return _reviews.doc(reviewId).update({
      ClinicalReviewSchema.reviewNotesField: reviewNotes,
    });
  }

  Future<void> createDisable({
    required Map<String, dynamic> entryRef,
    required String reason,
    required String actionBy,
  }) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('reason is required');
    }
    final now = DateTime.now().toUtc();
    return _actions.add({
      ClinicalReviewSchema.entryRefField: entryRef,
      ClinicalReviewSchema.actionField: ClinicalReviewSchema.actionDisable,
      ClinicalReviewSchema.actionByField: actionBy,
      ClinicalReviewSchema.actionAtField: FieldValue.serverTimestamp(),
      ClinicalReviewSchema.reasonField: trimmed,
      ClinicalReviewSchema.resolveByField: Timestamp.fromDate(
        ClinicalReviewSchema.resolveByFrom(now),
      ),
      ClinicalReviewSchema.resolutionField: null,
      ClinicalReviewSchema.resolvedByField: null,
      ClinicalReviewSchema.resolvedAtField: null,
    });
  }

  Future<void> resolveEmergency({
    required String actionId,
    required String resolution,
    required String resolvedBy,
  }) {
    if (!ClinicalReviewSchema.emergencyResolutions.contains(resolution)) {
      throw ArgumentError.value(resolution, 'resolution');
    }
    return _actions.doc(actionId).update({
      ClinicalReviewSchema.resolutionField: resolution,
      ClinicalReviewSchema.resolvedByField: resolvedBy,
      ClinicalReviewSchema.resolvedAtField: FieldValue.serverTimestamp(),
    });
  }

  /// Live dart entries that have a matching approved review (disable targets).
  List<LiveClinicalEvidenceSite> approvedLiveEntries({
    required List<LiveClinicalEvidenceSite> liveSites,
    required List<ClinicalEvidenceReviewDoc> reviews,
    required List<EmergencyActionDoc> actions,
  }) {
    final report = ClinicalEvidenceComplianceChecker.check(
      liveSites: liveSites,
      reviews: reviews,
      emergencyActions: const [],
    );
    final failing = report.failures.map((f) => f.site.displayRef).toSet();
    return [
      for (final site in liveSites)
        if (!failing.contains(site.displayRef)) site,
    ];
  }

  static int _bySubmittedDesc(
    ClinicalEvidenceReviewDoc a,
    ClinicalEvidenceReviewDoc b,
  ) {
    final at = b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return at.compareTo(bt);
  }

  static List<ClinicalEvidenceReviewDoc> _reviewsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return [
      for (final doc in snap.docs)
        ClinicalEvidenceReviewDoc.fromMap(doc.id, doc.data()),
    ];
  }
}
