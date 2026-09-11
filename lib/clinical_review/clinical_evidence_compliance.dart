import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';

enum ComplianceFailureReason {
  neverReviewed,
  contentMismatch,
  disabledUnresolved,
}

class ComplianceFailure {
  final LiveClinicalEvidenceSite site;
  final ComplianceFailureReason reason;
  final String detail;

  const ComplianceFailure({
    required this.site,
    required this.reason,
    required this.detail,
  });

  String get reasonLabel {
    switch (reason) {
      case ComplianceFailureReason.neverReviewed:
        return 'never-reviewed';
      case ComplianceFailureReason.contentMismatch:
        return 'content-mismatch';
      case ComplianceFailureReason.disabledUnresolved:
        return 'disabled-unresolved';
    }
  }

  /// One block printed by the enforcement script.
  String toReportBlock() {
    final e = site.evidence;
    return 'FAIL  $reasonLabel  ${site.displayRef}\n'
        '      title: ${e.title}\n'
        '      doi: ${e.doi}${e.pmid != null && e.pmid!.isNotEmpty ? '  pmid: ${e.pmid}' : ''}\n'
        '      $detail';
  }
}

class ComplianceReport {
  final List<LiveClinicalEvidenceSite> liveSites;
  final List<ComplianceFailure> failures;
  final int approvedReviewCount;
  final int openDisableCount;

  const ComplianceReport({
    required this.liveSites,
    required this.failures,
    required this.approvedReviewCount,
    required this.openDisableCount,
  });

  bool get ok => failures.isEmpty;
  int get liveEntryCount => liveSites.length;
}

/// A `clinicalEvidenceReviews/{id}` document, independent of the Firestore SDK.
class ClinicalEvidenceReviewDoc {
  final String id;
  final String status;
  final Map<String, dynamic> entryRef;
  final Map<String, dynamic> proposedContent;
  final Map<String, dynamic>? previousContent;
  final String? submittedBy;
  final DateTime? submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? gradeLevel;

  const ClinicalEvidenceReviewDoc({
    required this.id,
    required this.status,
    required this.entryRef,
    required this.proposedContent,
    this.previousContent,
    this.submittedBy,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    this.gradeLevel,
  });

  factory ClinicalEvidenceReviewDoc.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final previous = data[ClinicalReviewSchema.previousContentField];
    return ClinicalEvidenceReviewDoc(
      id: id,
      status: (data[ClinicalReviewSchema.statusField] ?? '').toString(),
      entryRef: _asStringKeyedMap(data[ClinicalReviewSchema.entryRefField]),
      proposedContent:
          _asStringKeyedMap(data[ClinicalReviewSchema.proposedContentField]),
      previousContent: previous == null ? null : _asStringKeyedMap(previous),
      submittedBy: _nullableString(data[ClinicalReviewSchema.submittedByField]),
      submittedAt: _asDateTime(data[ClinicalReviewSchema.submittedAtField]),
      reviewedBy: _nullableString(data[ClinicalReviewSchema.reviewedByField]),
      reviewedAt: _asDateTime(data[ClinicalReviewSchema.reviewedAtField]),
      reviewNotes: _nullableString(data[ClinicalReviewSchema.reviewNotesField]),
      gradeLevel: _nullableString(data[ClinicalReviewSchema.gradeLevelField]),
    );
  }

  bool get isApproved => status == ClinicalReviewSchema.statusApproved;
  bool get isPending => status == ClinicalReviewSchema.statusPending;
  bool get isEdit => previousContent != null && previousContent!.isNotEmpty;

  String get conditionLabel =>
      _nullableString(entryRef[ClinicalReviewSchema.conditionField]) ?? '';

  String get locationLabel =>
      _nullableString(entryRef[ClinicalReviewSchema.locationField]) ?? '';

  String get proposedTitle =>
      _nullableString(proposedContent['title']) ??
      _nullableString(entryRef[ClinicalReviewSchema.titleField]) ??
      '';

  String? get condition =>
      conditionLabel.isEmpty ? null : conditionLabel;

  String? get location =>
      locationLabel.isEmpty ? null : locationLabel;

  String get displayRef {
    final base = '$conditionLabel / $locationLabel';
    if (base.trim() == '/') return id;
    return base;
  }
}

/// A `clinicalEvidenceEmergencyActions/{id}` document.
class EmergencyActionDoc {
  final String id;
  final String action;
  final Map<String, dynamic> entryRef;
  final String? resolution;
  final DateTime? resolveBy;
  final String? actionBy;
  final DateTime? actionAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? reason;

  const EmergencyActionDoc({
    required this.id,
    required this.action,
    required this.entryRef,
    this.resolution,
    this.resolveBy,
    this.actionBy,
    this.actionAt,
    this.resolvedBy,
    this.resolvedAt,
    this.reason,
  });

  factory EmergencyActionDoc.fromMap(String id, Map<String, dynamic> data) {
    return EmergencyActionDoc(
      id: id,
      action: (data[ClinicalReviewSchema.actionField] ?? '').toString(),
      entryRef: _asStringKeyedMap(data[ClinicalReviewSchema.entryRefField]),
      resolution: _nullableString(data[ClinicalReviewSchema.resolutionField]),
      resolveBy: _asDateTime(data[ClinicalReviewSchema.resolveByField]),
      actionBy: _nullableString(data[ClinicalReviewSchema.actionByField]),
      actionAt: _asDateTime(data[ClinicalReviewSchema.actionAtField]),
      resolvedBy: _nullableString(data[ClinicalReviewSchema.resolvedByField]),
      resolvedAt: _asDateTime(data[ClinicalReviewSchema.resolvedAtField]),
      reason: _nullableString(data[ClinicalReviewSchema.reasonField]),
    );
  }

  bool get isOpenDisable =>
      action == ClinicalReviewSchema.actionDisable &&
      (resolution == null || resolution!.isEmpty);

  String? get condition =>
      _nullableString(entryRef[ClinicalReviewSchema.conditionField]);

  String? get location =>
      _nullableString(entryRef[ClinicalReviewSchema.locationField]);

  String? get title =>
      _nullableString(entryRef[ClinicalReviewSchema.titleField]);
}

/// Pure matching logic: live dart entries vs review / emergency-action docs.
///
/// No Firestore SDK import — the CLI script and the FakeFirebaseFirestore
/// adapter both feed this the same document shape.
class ClinicalEvidenceComplianceChecker {
  static ComplianceReport check({
    required List<LiveClinicalEvidenceSite> liveSites,
    required List<ClinicalEvidenceReviewDoc> reviews,
    required List<EmergencyActionDoc> emergencyActions,
  }) {
    final approved = reviews.where((r) => r.isApproved).toList();
    final openDisables =
        emergencyActions.where((a) => a.isOpenDisable).toList();
    final failures = <ComplianceFailure>[];

    for (final site in liveSites) {
      final disable = _matchingOpenDisable(site, openDisables);
      if (disable != null) {
        final deadline = disable.resolveBy;
        final deadlineText = deadline == null
            ? 'no resolveBy timestamp stored'
            : 'resolveBy ${deadline.toUtc().toIso8601String()}';
        failures.add(ComplianceFailure(
          site: site,
          reason: ComplianceFailureReason.disabledUnresolved,
          detail:
              'open emergency disable ${disable.id} ($deadlineText). '
              'This entry is disabled pending human resolution — it must not '
              'ship in live data. Not an automatic revert; a person must '
              'restore or revoke-permanently.',
        ));
        continue;
      }

      final atLocation = approved.where((r) => _entryRefMatches(r, site)).toList();
      if (atLocation.isEmpty) {
        failures.add(ComplianceFailure(
          site: site,
          reason: ComplianceFailureReason.neverReviewed,
          detail:
              'no approved clinicalEvidenceReviews record for this entryRef.',
        ));
        continue;
      }

      final matching = atLocation.where((r) => _contentMatches(site.evidence, r));
      if (matching.isEmpty) {
        final diffs = atLocation
            .map((r) => _contentDiff(site.evidence, r).join(', '))
            .where((s) => s.isNotEmpty)
            .toSet()
            .join('; ');
        failures.add(ComplianceFailure(
          site: site,
          reason: ComplianceFailureReason.contentMismatch,
          detail:
              '${atLocation.length} approved review(s) exist for this '
              'entryRef but proposedContent does not match live fields '
              '(title, authors, doi, pmid, keyFinding, gradeLevel).'
              '${diffs.isEmpty ? '' : ' Differing: $diffs'}',
        ));
      }
    }

    return ComplianceReport(
      liveSites: liveSites,
      failures: failures,
      approvedReviewCount: approved.length,
      openDisableCount: openDisables.length,
    );
  }

  static EmergencyActionDoc? _matchingOpenDisable(
    LiveClinicalEvidenceSite site,
    List<EmergencyActionDoc> openDisables,
  ) {
    for (final action in openDisables) {
      if (action.condition != site.conditionKey) continue;
      if (action.location != site.location) continue;
      final title = action.title;
      if (title != null && title.isNotEmpty && title != site.evidence.title) {
        continue;
      }
      return action;
    }
    return null;
  }

  static bool _entryRefMatches(
    ClinicalEvidenceReviewDoc review,
    LiveClinicalEvidenceSite site,
  ) {
    return review.conditionLabel == site.conditionKey &&
        review.locationLabel == site.location;
  }

  static bool _contentMatches(
    ClinicalEvidence live,
    ClinicalEvidenceReviewDoc review,
  ) {
    return _contentDiff(live, review).isEmpty;
  }

  static List<String> _contentDiff(
    ClinicalEvidence live,
    ClinicalEvidenceReviewDoc review,
  ) {
    final proposed = review.proposedContent;
    final approvedGrade = _nullableString(review.gradeLevel) ??
        _nullableString(proposed['gradeLevel']);
    final diffs = <String>[];

    void cmp(String field, String? liveValue, String? approvedValue) {
      if (_norm(liveValue) != _norm(approvedValue)) {
        diffs.add(field);
      }
    }

    cmp('title', live.title, _nullableString(proposed['title']));
    cmp('authors', live.authors, _nullableString(proposed['authors']));
    cmp('doi', live.doi, _nullableString(proposed['doi']));
    cmp('pmid', live.pmid, _nullableString(proposed['pmid']));
    cmp('keyFinding', live.keyFinding, _nullableString(proposed['keyFinding']));
    cmp('gradeLevel', live.gradeLevel, approvedGrade);
    return diffs;
  }
}

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String _norm(String? value) => (value ?? '').trim();

DateTime? _asDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  // Firestore Timestamp (SDK) exposes toDate(); duck-type without importing.
  try {
    final dynamic d = value;
    final toDate = d.toDate;
    if (toDate is Function) {
      final result = toDate();
      if (result is DateTime) return result;
    }
  } catch (_) {}
  return null;
}
