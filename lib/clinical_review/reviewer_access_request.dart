/// Mirrors functions/src/schema.ts. A user-initiated request for
/// clinicalReviewer access — created by the client (allowed by
/// firestore.rules), decided only by the approveClinicalReviewer /
/// rejectReviewerAccess Cloud Functions (Admin SDK, not client rules).
class ReviewerAccessRequestDoc {
  final String id;
  final String email;
  final String uid;
  final String? displayName;
  final String? note;
  final String status;
  final DateTime? requestedAt;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionNote;

  const ReviewerAccessRequestDoc({
    required this.id,
    required this.email,
    required this.uid,
    this.displayName,
    this.note,
    required this.status,
    this.requestedAt,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
  });

  static const statusPending = 'pending';
  static const statusApproved = 'approved';
  static const statusRejected = 'rejected';

  bool get isPending => status == statusPending;

  factory ReviewerAccessRequestDoc.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? asDate(Object? value) {
      if (value == null) return null;
      // Firestore Timestamp has a toDate(); avoid importing cloud_firestore
      // here just for the type by duck-typing via dynamic.
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    String? asString(Object? value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return ReviewerAccessRequestDoc(
      id: id,
      email: (data['email'] ?? '').toString(),
      uid: (data['uid'] ?? '').toString(),
      displayName: asString(data['displayName']),
      note: asString(data['note']),
      status: (data['status'] ?? '').toString(),
      requestedAt: asDate(data['requestedAt']),
      decidedBy: asString(data['decidedBy']),
      decidedAt: asDate(data['decidedAt']),
      decisionNote: asString(data['decisionNote']),
    );
  }
}

/// A row from `users` with a clinical staff role — for the Reviewers tab's
/// "current reviewers" list.
class ClinicalStaffUser {
  final String uid;
  final String? email;
  final String role;

  const ClinicalStaffUser({
    required this.uid,
    required this.role,
    this.email,
  });
}
