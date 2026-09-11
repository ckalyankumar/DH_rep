import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';
import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_evidence_firestore_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:dhealth/clinical_review/clinical_roles.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

ClinicalEvidence _paper({
  String title = 'Paper A',
  String authors = 'Doe J',
  String doi = '10.1000/test-a',
  String? pmid,
  String keyFinding = 'Finding A',
  String? gradeLevel = '1B',
  String url = 'https://example.test/a',
  String year = '2024',
}) {
  return ClinicalEvidence(
    title: title,
    authors: authors,
    year: year,
    journal: 'Test Journal',
    doi: doi,
    pmid: pmid,
    url: url,
    keyFinding: keyFinding,
    citationCount: 10,
    evidenceType: 'review',
    gradeLevel: gradeLevel,
  );
}

LiveClinicalEvidenceSite _site({
  String conditionKey = 'psoriasis',
  String location = 'Trigger: Psychological Stress',
  int ordinal = 0,
  ClinicalEvidence? evidence,
}) {
  final paper = evidence ?? _paper();
  return LiveClinicalEvidenceSite(
    conditionKey: conditionKey,
    conditionDisplayName: 'Psoriasis',
    location: location,
    ordinal: ordinal,
    evidence: paper,
  );
}

Map<String, dynamic> _review({
  String status = ClinicalReviewSchema.statusApproved,
  String condition = 'psoriasis',
  String location = 'Trigger: Psychological Stress',
  required ClinicalEvidence content,
  String? gradeLevel,
}) {
  return {
    ClinicalReviewSchema.statusField: status,
    ClinicalReviewSchema.entryRefField: {
      ClinicalReviewSchema.conditionField: condition,
      ClinicalReviewSchema.locationField: location,
      ClinicalReviewSchema.ordinalField: 0,
      ClinicalReviewSchema.titleField: content.title,
    },
    ClinicalReviewSchema.proposedContentField: content.toProposedContent(),
    ClinicalReviewSchema.gradeLevelField: gradeLevel ?? content.gradeLevel,
    ClinicalReviewSchema.submittedByField: 'test-submitter',
  };
}

Map<String, dynamic> _disable({
  String condition = 'psoriasis',
  String location = 'Trigger: Psychological Stress',
  String? title,
  String? resolution,
}) {
  return {
    ClinicalReviewSchema.actionField: ClinicalReviewSchema.actionDisable,
    ClinicalReviewSchema.entryRefField: {
      ClinicalReviewSchema.conditionField: condition,
      ClinicalReviewSchema.locationField: location,
      if (title != null) ClinicalReviewSchema.titleField: title,
    },
    ClinicalReviewSchema.actionByField: 'admin',
    ClinicalReviewSchema.reasonField: 'Safety hold pending clinician check',
    ClinicalReviewSchema.resolutionField: resolution,
    ClinicalReviewSchema.resolveByField:
        DateTime.utc(2026, 9, 13, 12),
  };
}

void main() {
  group('ClinicalEvidenceCatalog', () {
    test('walks psoriasis and eczema live entries from dart files', () {
      final sites = ClinicalEvidenceCatalog.allLiveSites();
      expect(sites, isNotEmpty);
      expect(sites.any((s) => s.conditionKey == 'psoriasis'), isTrue);
      expect(sites.any((s) => s.conditionKey == 'eczema'), isTrue);
      expect(
        sites.any((s) => s.location == 'Trigger: Psychological Stress'),
        isTrue,
      );
      expect(
        sites.any((s) => s.location.startsWith('Treatment:')),
        isTrue,
      );
      expect(
        sites.any((s) => s.location == 'Key research paper'),
        isTrue,
      );
    });
  });

  group('ClinicalRoles', () {
    test('canonicalizes protected roles without collapsing to patient', () {
      expect(ClinicalRoles.canonicalize('clinicalAdmin'), 'clinicalAdmin');
      expect(ClinicalRoles.canonicalize('CLINICALREVIEWER'), 'clinicalReviewer');
      expect(ClinicalRoles.isProtected('clinicalAdmin'), isTrue);
      expect(ClinicalRoles.isProtected('doctor'), isFalse);
      expect(ClinicalRoles.canonicalize('admin'), isNull);
    });
  });

  group('schema matching via FakeFirebaseFirestore', () {
    late FakeFirebaseFirestore db;
    late LiveClinicalEvidenceSite live;

    setUp(() {
      db = FakeFirebaseFirestore();
      live = _site();
    });

    Future<ComplianceReport> run() {
      return ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live],
      );
    }

    test('empty reviews → never-reviewed', () async {
      final report = await run();
      expect(report.ok, isFalse);
      expect(report.failures, hasLength(1));
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.neverReviewed,
      );
    });

    test('approved review whose clinical fields match → pass', () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: live.evidence));

      final report = await run();
      expect(report.ok, isTrue);
      expect(report.failures, isEmpty);
    });

    test('incidental fields may differ without failing', () async {
      final approved = _paper(url: 'https://other.test', year: '1999');
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: approved));

      final report = await run();
      expect(report.ok, isTrue, reason: 'url/year/journal are not compared');
    });

    test('approved review with different title → content-mismatch', () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: _paper(title: 'Different title')));

      final report = await run();
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.contentMismatch,
      );
      expect(report.failures.single.detail, contains('title'));
    });

    test('approved review with different keyFinding → content-mismatch',
        () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: _paper(keyFinding: 'A different statistic')));

      final report = await run();
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.contentMismatch,
      );
      expect(report.failures.single.detail, contains('keyFinding'));
    });

    test('approved review with different doi → content-mismatch', () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: _paper(doi: '10.1000/other')));

      final report = await run();
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.contentMismatch,
      );
      expect(report.failures.single.detail, contains('doi'));
    });

    test('approved review with different authors → content-mismatch', () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: _paper(authors: 'Smith A')));

      final report = await run();
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.contentMismatch,
      );
      expect(report.failures.single.detail, contains('authors'));
    });

    test('pending / rejected / needs_changes do not count as approval',
        () async {
      for (final status in [
        ClinicalReviewSchema.statusPending,
        ClinicalReviewSchema.statusRejected,
        ClinicalReviewSchema.statusNeedsChanges,
      ]) {
        final isolated = FakeFirebaseFirestore();
        await isolated
            .collection(ClinicalReviewSchema.reviewsCollection)
            .doc(status)
            .set(_review(status: status, content: live.evidence));
        final report = await ClinicalEvidenceFirestoreCompliance.check(
          firestore: isolated,
          liveSites: [live],
        );
        expect(
          report.failures.single.reason,
          ComplianceFailureReason.neverReviewed,
          reason: '$status must not satisfy the live-data gate',
        );
      }
    });

    test('pmid null and empty string are equivalent', () async {
      live = _site(evidence: _paper(pmid: null));
      final stored = _paper(pmid: '');
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: stored));

      final report = await run();
      expect(report.ok, isTrue);
    });

    test('reviewer gradeLevel on the review doc is what live must match',
        () async {
      live = _site(evidence: _paper(gradeLevel: '1A'));
      final proposed = _paper(gradeLevel: '4');
      await db.collection(ClinicalReviewSchema.reviewsCollection).doc('r1').set(
            _review(content: proposed, gradeLevel: '1A'),
          );

      final report = await run();
      expect(report.ok, isTrue);
    });

    test('live gradeLevel differing from approved grade → content-mismatch',
        () async {
      live = _site(evidence: _paper(gradeLevel: '4'));
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: _paper(gradeLevel: '1A')));

      final report = await run();
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.contentMismatch,
      );
      expect(report.failures.single.detail, contains('gradeLevel'));
    });

    test('approved review for a different entryRef does not count', () async {
      await db.collection(ClinicalReviewSchema.reviewsCollection).doc('r1').set(
            _review(
              content: live.evidence,
              location: 'Trigger: Smoking',
            ),
          );

      final report = await run();
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.neverReviewed,
      );
    });
  });

  group('disable-action handling', () {
    late FakeFirebaseFirestore db;
    late LiveClinicalEvidenceSite live;

    setUp(() {
      db = FakeFirebaseFirestore();
      live = _site();
    });

    test('open disable flags disabled-unresolved even when approved', () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: live.evidence));
      await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .doc('d1')
          .set(_disable(title: live.evidence.title));

      final report = await ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live],
      );
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.disabledUnresolved,
      );
      expect(report.openDisableCount, 1);
    });

    test('resolved disable (restored) does not fail a matching approval',
        () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: live.evidence));
      await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .doc('d1')
          .set(_disable(
            title: live.evidence.title,
            resolution: ClinicalReviewSchema.resolutionRestored,
          ));

      final report = await ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live],
      );
      expect(report.ok, isTrue);
    });

    test('revoked-permanently disable is not an open disable', () async {
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: live.evidence));
      await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .doc('d1')
          .set(_disable(
            title: live.evidence.title,
            resolution: ClinicalReviewSchema.resolutionRevokedPermanently,
          ));

      final report = await ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live],
      );
      expect(report.ok, isTrue);
    });

    test('title-scoped disable does not affect a different paper at same location',
        () async {
      final other = _site(
        ordinal: 1,
        evidence: _paper(title: 'Paper B', doi: '10.1000/test-b'),
      );
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: live.evidence));
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r2')
          .set(_review(content: other.evidence));
      await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .doc('d1')
          .set(_disable(title: 'Paper B'));

      final report = await ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live, other],
      );
      expect(report.failures, hasLength(1));
      expect(report.failures.single.site.evidence.title, 'Paper B');
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.disabledUnresolved,
      );
    });

    test('disable without title applies to every paper at that location',
        () async {
      final other = _site(
        ordinal: 1,
        evidence: _paper(title: 'Paper B', doi: '10.1000/test-b'),
      );
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r1')
          .set(_review(content: live.evidence));
      await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('r2')
          .set(_review(content: other.evidence));
      await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .doc('d1')
          .set(_disable());

      final report = await ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live, other],
      );
      expect(report.failures, hasLength(2));
      expect(
        report.failures.every(
          (f) => f.reason == ComplianceFailureReason.disabledUnresolved,
        ),
        isTrue,
      );
    });

    test('open disable on a never-reviewed entry is still disabled-unresolved',
        () async {
      await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .doc('d1')
          .set(_disable(title: live.evidence.title));

      final report = await ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live],
      );
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.disabledUnresolved,
      );
    });
  });

  group('Timestamp resolveBy on emergency actions', () {
    test('FakeFirebaseFirestore Timestamp is accepted by the parser', () async {
      final db = FakeFirebaseFirestore();
      final live = _site();
      await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .doc('d1')
          .set({
        ..._disable(title: live.evidence.title),
        ClinicalReviewSchema.resolveByField: Timestamp.fromDate(
          DateTime.utc(2026, 9, 13),
        ),
      });

      final report = await ClinicalEvidenceFirestoreCompliance.check(
        firestore: db,
        liveSites: [live],
      );
      expect(
        report.failures.single.reason,
        ComplianceFailureReason.disabledUnresolved,
      );
      expect(report.failures.single.detail, contains('resolveBy'));
    });
  });
}
