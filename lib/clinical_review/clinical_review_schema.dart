/// Firestore collection names, statuses, and field names for the clinical
/// evidence review workflow. Keep in lockstep with `firestore.rules`.
class ClinicalReviewSchema {
  static const reviewsCollection = 'clinicalEvidenceReviews';
  static const emergencyActionsCollection = 'clinicalEvidenceEmergencyActions';

  static const statusPending = 'pending';
  static const statusApproved = 'approved';
  static const statusRejected = 'rejected';
  static const statusNeedsChanges = 'needs_changes';

  static const gradeLevels = ['1A', '1B', '2A', '2B', '3', '4'];

  /// Trimmed `reviewNotes` must be at least this long to Approve. Reject /
  /// Request changes do not require notes. Chosen to block a one-character
  /// unlock without imposing a word-count rubric.
  static const approvalNotesMinLength = 12;

  static const Set<String> reviewStatuses = {
    statusPending,
    statusApproved,
    statusRejected,
    statusNeedsChanges,
  };

  static const actionDisable = 'disable';
  static const actionRestore = 'restore';

  static const Set<String> emergencyActions = {
    actionDisable,
    actionRestore,
  };

  static const resolutionRevokedPermanently = 'revoked-permanently';
  static const resolutionRestored = 'restored';

  static const Set<String> emergencyResolutions = {
    resolutionRevokedPermanently,
    resolutionRestored,
  };

  /// How long an emergency disable may stay open before a human must resolve
  /// it through the normal review flow. Enforced as a process rule (visible
  /// via [resolveByField]), not as an automatic revert.
  static const emergencyResolveWindow = Duration(hours: 72);

  // ── review document fields ──────────────────────────────────────────
  static const statusField = 'status';
  static const entryRefField = 'entryRef';
  static const proposedContentField = 'proposedContent';
  static const previousContentField = 'previousContent';
  static const submittedByField = 'submittedBy';
  static const submittedAtField = 'submittedAt';
  static const reviewedByField = 'reviewedBy';
  static const reviewedAtField = 'reviewedAt';
  static const reviewNotesField = 'reviewNotes';
  static const gradeLevelField = 'gradeLevel';

  // ── entryRef map ────────────────────────────────────────────────────
  static const conditionField = 'condition';
  static const locationField = 'location';
  static const ordinalField = 'ordinal';
  static const titleField = 'title';

  // ── clinically compared proposedContent fields ──────────────────────
  /// Fields that must match the live [ClinicalEvidence] exactly for an
  /// approved review to count. Incidental fields (url, citationCount,
  /// evidenceType, year, journal) are stored on the review but not compared.
  static const clinicallyComparedFields = [
    'title',
    'authors',
    'doi',
    'pmid',
    'keyFinding',
    'gradeLevel',
  ];

  // ── emergency action fields ─────────────────────────────────────────
  static const actionField = 'action';
  static const actionByField = 'actionBy';
  static const actionAtField = 'actionAt';
  static const reasonField = 'reason';
  static const resolvedByField = 'resolvedBy';
  static const resolvedAtField = 'resolvedAt';
  static const resolutionField = 'resolution';
  static const resolveByField = 'resolveBy';

  static DateTime resolveByFrom(DateTime actionAt) =>
      actionAt.add(emergencyResolveWindow);
}
