import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhealth/clinical_review/clinical_review_portal_service.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:dhealth/clinical_review_portal/portal_app.dart';
import 'package:dhealth/clinical_review_portal/portal_auth.dart';
import 'package:dhealth/clinical_review_portal/portal_theme.dart';
import 'package:dhealth/clinical_review_portal/portal_widgets.dart';
import 'package:dhealth/clinical_review_portal/review_detail_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements PortalAuth {
  _FakeAuth([this.identity]);

  PortalIdentity? identity;
  final signedIn = <(String, String)>[];

  @override
  Stream<PortalIdentity?> authStateChanges() => Stream.value(identity);

  @override
  Future<void> signInWithEmail(String email, String password) async {
    signedIn.add((email, password));
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {
    identity = null;
  }
}

Future<void> _seedUser(
  FakeFirebaseFirestore db,
  String uid,
  String role,
) {
  return db.collection('users').doc(uid).set({
    'profile': {'role': role},
  });
}

Future<void> _seedPending(FakeFirebaseFirestore db) {
  return db
      .collection(ClinicalReviewSchema.reviewsCollection)
      .doc('rev1')
      .set({
    ClinicalReviewSchema.statusField: ClinicalReviewSchema.statusPending,
    ClinicalReviewSchema.entryRefField: {
      'condition': 'psoriasis',
      'location': 'Trigger: Psychological Stress',
      'ordinal': 0,
      'title': 'Stress paper',
    },
    ClinicalReviewSchema.proposedContentField: {
      'title': 'Stress paper',
      'authors': 'Doe J',
      'year': '2024',
      'journal': 'Test',
      'doi': '10.1000/test',
      'pmid': '26025581',
      'keyFinding': 'A finding',
      'mechanism': 'Test mechanism from source',
      'preventionStrategy': 'Test prevention from source',
      'gradeLevel': '2A',
    },
    ClinicalReviewSchema.submittedByField: 'ai-session-1',
    ClinicalReviewSchema.submittedAtField: Timestamp.fromDate(
      DateTime.utc(2026, 9, 10, 12),
    ),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('source identifier URLs', () {
    test('doi resolver skips placeholders and unwraps doi.org prefixes', () {
      expect(doiResolverUri(null), isNull);
      expect(doiResolverUri(''), isNull);
      expect(doiResolverUri('XXX'), isNull);
      expect(
        doiResolverUri('10.1000/test'),
        Uri.parse('https://doi.org/10.1000/test'),
      );
      expect(
        doiResolverUri('https://doi.org/10.1000/test'),
        Uri.parse('https://doi.org/10.1000/test'),
      );
    });

    test('pubmed URL requires a numeric PMID', () {
      expect(pubmedUri(null), isNull);
      expect(pubmedUri(''), isNull);
      expect(pubmedUri('PMC10860266'), isNull);
      expect(
        pubmedUri('26025581'),
        Uri.parse('https://pubmed.ncbi.nlm.nih.gov/26025581'),
      );
    });
  });

  group('ClinicalReviewPortalService (Firestore SDK)', () {
    test('approve writes status, GRADE, reviewedBy via Firestore update',
        () async {
      final db = FakeFirebaseFirestore();
      await _seedPending(db);
      final service = ClinicalReviewPortalService(firestore: db);

      await service.decideReview(
        reviewId: 'rev1',
        status: ClinicalReviewSchema.statusApproved,
        reviewedBy: 'reviewer@dhealth.test',
        reviewNotes: 'Looks correct',
        gradeLevel: '1B',
      );

      final snap = await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('rev1')
          .get();
      final data = snap.data()!;
      expect(data['status'], 'approved');
      expect(data['gradeLevel'], '1B');
      expect(data['reviewedBy'], 'reviewer@dhealth.test');
      expect(data['reviewNotes'], 'Looks correct');
      expect(data['reviewedAt'], isNotNull);
    });

    test('approve without verification notes throws', () async {
      final db = FakeFirebaseFirestore();
      await _seedPending(db);
      final service = ClinicalReviewPortalService(firestore: db);
      expect(
        () => service.decideReview(
          reviewId: 'rev1',
          status: ClinicalReviewSchema.statusApproved,
          reviewedBy: 'reviewer@dhealth.test',
          reviewNotes: 'x',
          gradeLevel: '1B',
        ),
        throwsArgumentError,
      );
    });

    test('createDisable requires a reason and writes an open disable', () async {
      final db = FakeFirebaseFirestore();
      final service = ClinicalReviewPortalService(firestore: db);
      expect(
        () => service.createDisable(
          entryRef: {'condition': 'psoriasis', 'location': 'Trigger: X'},
          reason: '  ',
          actionBy: 'admin@test',
        ),
        throwsArgumentError,
      );

      await service.createDisable(
        entryRef: {
          'condition': 'psoriasis',
          'location': 'Trigger: Psychological Stress',
          'title': 'Stress paper',
        },
        reason: 'Claim contradicts the cited paper',
        actionBy: 'admin@test',
      );
      final docs = await db
          .collection(ClinicalReviewSchema.emergencyActionsCollection)
          .get();
      expect(docs.docs, hasLength(1));
      final data = docs.docs.single.data();
      expect(data['action'], 'disable');
      expect(data['reason'], 'Claim contradicts the cited paper');
      expect(data['resolution'], isNull);
    });
  });

  group('portal auth gate', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1440, 900);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });
    testWidgets('signed out shows login, not the queue', (tester) async {
      await tester.pumpWidget(
        ClinicalReviewPortalApp(
          auth: _FakeAuth(),
          service: ClinicalReviewPortalService(
            firestore: FakeFirebaseFirestore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clinical Evidence Review'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Pending reviews'), findsNothing);
    });

    testWidgets('patient role is stopped at the no-access screen',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedUser(db, 'u1', 'patient');
      await tester.pumpWidget(
        ClinicalReviewPortalApp(
          auth: _FakeAuth(
            const PortalIdentity(uid: 'u1', email: 'p@test.com'),
          ),
          service: ClinicalReviewPortalService(firestore: db),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You don’t have access'), findsOneWidget);
      expect(find.text('Pending reviews'), findsNothing);
      expect(find.text('Emergency'), findsNothing);
    });

    testWidgets('clinicalReviewer sees queue, not Emergency', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedUser(db, 'u2', 'clinicalReviewer');
      await _seedPending(db);
      await tester.pumpWidget(
        ClinicalReviewPortalApp(
          auth: _FakeAuth(
            const PortalIdentity(uid: 'u2', email: 'rev@test.com'),
          ),
          service: ClinicalReviewPortalService(firestore: db),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pending reviews'), findsOneWidget);
      expect(find.text('Trigger: Psychological Stress'), findsOneWidget);
      expect(find.text('Emergency'), findsNothing);
    });

    testWidgets('clinicalAdmin sees Emergency destination', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedUser(db, 'u3', 'clinicalAdmin');
      await tester.pumpWidget(
        ClinicalReviewPortalApp(
          auth: _FakeAuth(
            const PortalIdentity(uid: 'u3', email: 'admin@test.com'),
          ),
          service: ClinicalReviewPortalService(firestore: db),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Emergency'), findsOneWidget);
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Audit'), findsOneWidget);
    });
  });

  group('review detail', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize =
          const Size(1440, 900);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    Future<void> pumpDetail(
      WidgetTester tester,
      FakeFirebaseFirestore db,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PortalTheme.data,
          home: ReviewDetailScreen(
            service: ClinicalReviewPortalService(firestore: db),
            reviewId: 'rev1',
            reviewedBy: 'rev@test.com',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> selectGrade1A(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1A').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value,
        '1A',
        reason: 'GRADE must actually stick — a missed dropdown tap would '
            'leave Approve disabled for the wrong reason',
      );
    }

    ElevatedButton approveButton(WidgetTester tester) {
      return tester.widget<ElevatedButton>(
        find.byKey(ReviewDetailScreen.approveButtonKey),
      );
    }

    Color? approvePaintedColor(WidgetTester tester) {
      final materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byKey(ReviewDetailScreen.approveButtonKey),
          matching: find.byType(Material),
        ),
      );
      expect(materials, isNotEmpty);
      return materials.last.color;
    }

    Future<String?> reviewStatus(FakeFirebaseFirestore db) async {
      final snap = await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('rev1')
          .get();
      return snap.data()?['status'] as String?;
    }

    test('reviewApprovalEnabled requires GRADE and long notes independently',
        () {
      expect(
        reviewApprovalEnabled(busy: false, grade: null, notes: 'plenty of text here'),
        isFalse,
      );
      expect(
        reviewApprovalEnabled(busy: false, grade: '1A', notes: ''),
        isFalse,
      );
      expect(
        reviewApprovalEnabled(busy: false, grade: '1A', notes: '   '),
        isFalse,
      );
      expect(
        reviewApprovalEnabled(busy: false, grade: '1A', notes: 'too short'),
        isFalse,
      );
      expect(
        reviewApprovalEnabled(
          busy: false,
          grade: '1A',
          notes: 'Confirmed keyFinding against the cited full text',
        ),
        isTrue,
      );
      expect(
        reviewApprovalEnabled(
          busy: true,
          grade: '1A',
          notes: 'Confirmed keyFinding against the cited full text',
        ),
        isFalse,
      );
    });

    test('approve button style is gray when disabled, green when enabled', () {
      final style = reviewApproveButtonStyle();
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        isNot(PortalTheme.approved),
      );
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        const Color(0xFFC5CDD6),
      );
      expect(
        style.backgroundColor!.resolve(const <WidgetState>{}),
        PortalTheme.approved,
      );
    });

    testWidgets(
        'Approve stays disabled and gray after GRADE if notes are empty/short; tap does not approve',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedPending(db);
      await pumpDetail(tester, db);

      expect(find.text('SOURCE IDENTIFICATION'), findsOneWidget);
      expect(find.text('CLINICAL CLAIM SHOWN TO PATIENTS'), findsOneWidget);
      expect(approveButton(tester).enabled, isFalse);
      expect(approvePaintedColor(tester), isNot(PortalTheme.approved));

      await selectGrade1A(tester);

      expect(approveButton(tester).enabled, isFalse);
      expect(approveButton(tester).onPressed, isNull);
      expect(
        approvePaintedColor(tester),
        isNot(PortalTheme.approved),
        reason: 'Selecting GRADE must not paint Approve in the enabled green',
      );

      await tester.tap(find.byKey(ReviewDetailScreen.approveButtonKey));
      await tester.pumpAndSettle();
      expect(await reviewStatus(db), ClinicalReviewSchema.statusPending);

      await tester.enterText(
        find.byKey(ReviewDetailScreen.verificationNotesFieldKey),
        'too short',
      );
      await tester.pump();
      expect(approveButton(tester).enabled, isFalse);
      expect(approvePaintedColor(tester), isNot(PortalTheme.approved));

      await tester.tap(find.byKey(ReviewDetailScreen.approveButtonKey));
      await tester.pumpAndSettle();
      expect(await reviewStatus(db), ClinicalReviewSchema.statusPending);
    });

    testWidgets('DOI and PMID render as links to the real source',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedPending(db);
      await pumpDetail(tester, db);

      final doi = tester.widget<SourceLink>(find.byKey(const Key('source-link-doi')));
      expect(doi.uri, Uri.parse('https://doi.org/10.1000/test'));
      expect(doi.text, '10.1000/test');

      final pmid =
          tester.widget<SourceLink>(find.byKey(const Key('source-link-pmid')));
      expect(pmid.uri, Uri.parse('https://pubmed.ncbi.nlm.nih.gov/26025581'));
      expect(pmid.text, '26025581');
    });

    testWidgets(
        'Approve requires GRADE plus verification notes then writes approved',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedPending(db);
      await pumpDetail(tester, db);

      expect(find.text('Stress paper'), findsWidgets);
      expect(approveButton(tester).enabled, isFalse);

      await selectGrade1A(tester);
      expect(approveButton(tester).enabled, isFalse);
      expect(approvePaintedColor(tester), isNot(PortalTheme.approved));

      await tester.enterText(
        find.byKey(ReviewDetailScreen.verificationNotesFieldKey),
        'Confirmed keyFinding against the cited full text',
      );
      await tester.pump();
      expect(approveButton(tester).enabled, isTrue);
      expect(approveButton(tester).onPressed, isNotNull);
      expect(approvePaintedColor(tester), PortalTheme.approved);

      await tester.tap(find.byKey(ReviewDetailScreen.approveButtonKey));
      await tester.pumpAndSettle();

      final snap = await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('rev1')
          .get();
      expect(snap.data()?['status'], 'approved');
      expect(snap.data()?['gradeLevel'], '1A');
      expect(snap.data()?['reviewedBy'], 'rev@test.com');
      expect(
        snap.data()?['reviewNotes'],
        'Confirmed keyFinding against the cited full text',
      );
    });

    testWidgets('Reject works without verification notes', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedPending(db);
      await pumpDetail(tester, db);

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      final snap = await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('rev1')
          .get();
      expect(snap.data()?['status'], 'rejected');
      expect(snap.data()?['reviewedBy'], 'rev@test.com');
      expect(snap.data()?['reviewNotes'], isNull);
    });

    testWidgets('Request changes works without verification notes',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedPending(db);
      await pumpDetail(tester, db);

      await tester.tap(find.text('Request changes'));
      await tester.pumpAndSettle();

      final snap = await db
          .collection(ClinicalReviewSchema.reviewsCollection)
          .doc('rev1')
          .get();
      expect(snap.data()?['status'], 'needs_changes');
      expect(snap.data()?['reviewedBy'], 'rev@test.com');
      expect(snap.data()?['reviewNotes'], isNull);
    });

    testWidgets('Audit history shows saved verification notes', (tester) async {
      final db = FakeFirebaseFirestore();
      await _seedUser(db, 'u2', 'clinicalReviewer');
      await db.collection(ClinicalReviewSchema.reviewsCollection).doc('rev1').set({
        ClinicalReviewSchema.statusField: ClinicalReviewSchema.statusApproved,
        ClinicalReviewSchema.entryRefField: {
          'condition': 'psoriasis',
          'location': 'Trigger: Psychological Stress',
          'ordinal': 0,
          'title': 'Stress paper',
        },
        ClinicalReviewSchema.proposedContentField: {
          'title': 'Stress paper',
          'authors': 'Doe J',
          'doi': '10.1000/test',
          'keyFinding': 'A finding',
        },
        ClinicalReviewSchema.submittedByField: 'ai-session-1',
        ClinicalReviewSchema.submittedAtField: Timestamp.fromDate(
          DateTime.utc(2026, 9, 10, 12),
        ),
        ClinicalReviewSchema.reviewedByField: 'rev@test.com',
        ClinicalReviewSchema.reviewNotesField:
            'Confirmed keyFinding against the cited full text',
        ClinicalReviewSchema.gradeLevelField: '1A',
      });

      await tester.pumpWidget(
        ClinicalReviewPortalApp(
          auth: _FakeAuth(
            const PortalIdentity(uid: 'u2', email: 'rev@test.com'),
          ),
          service: ClinicalReviewPortalService(firestore: db),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Audit'));
      await tester.pumpAndSettle();

      expect(find.text('Verification notes'), findsOneWidget);
      expect(
        find.text('Confirmed keyFinding against the cited full text'),
        findsOneWidget,
      );
    });
  });
}
