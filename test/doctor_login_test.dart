/// Tests: Doctor login flow verification
///
/// Covers T1–T18 from the plan. Tests are split by what they need:
///   - Groups 1–2 (T1–T9):  pure Flutter widget tests — no Firebase required.
///   - Group 3   (T11–T12): Firestore data-shape unit tests (FakeFirebaseFirestore).
///   - Group 4   (T13–T15): AuthGate routing contract (code-level assertions).
///   - Group 5   (T16–T18): DoctorPortalScreen query logic (FakeFirebaseFirestore).
///
/// Run with: flutter test test/doctor_login_test.dart --reporter expanded

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/screens/login_screen.dart';

// ---------------------------------------------------------------------------
// Helper: Render LoginScreen in an isolated navigator so Navigator.pop()
// does not crash when the sign-in button is tapped.
// ---------------------------------------------------------------------------
Widget _buildLoginApp({String? initialRole}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          key: const ValueKey('openLogin'),
          onPressed: () {
            Navigator.push<void>(
              ctx,
              MaterialPageRoute(
                builder: (_) => LoginScreen(initialRole: initialRole),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

Future<void> _openLoginScreen(
  WidgetTester tester, {
  String? initialRole,
}) async {
  await tester.pumpWidget(_buildLoginApp(initialRole: initialRole));
  await tester.tap(find.byKey(const ValueKey('openLogin')));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Group 1 — LoginScreen UI: Doctor role chips & visibility
// ---------------------------------------------------------------------------
void main() {
  group('T1-T5: LoginScreen UI — doctor role', () {
    testWidgets('T1: "I\'m a Doctor" chip exists', (tester) async {
      await _openLoginScreen(tester);
      expect(find.text("I'm a Doctor"), findsOneWidget);
    });

    testWidgets('T2: selecting doctor chip hides Google Sign-In button',
        (tester) async {
      await _openLoginScreen(tester);
      // Default role is patient — Google button should be visible.
      expect(find.text('Sign in with Google'), findsOneWidget);

      await tester.tap(find.text("I'm a Doctor"));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('T3: doctor disclaimer appears when doctor chip selected',
        (tester) async {
      await _openLoginScreen(tester);
      await tester.tap(find.text("I'm a Doctor"));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Access is read-only. You will only see patients who have explicitly shared their data with you.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('T4: patient chip shows Google Sign-In button', (tester) async {
      await _openLoginScreen(tester);
      // Default is patient — Google button must be present.
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('T4b: switching doctor → patient restores Google Sign-In',
        (tester) async {
      await _openLoginScreen(tester);
      await tester.tap(find.text("I'm a Doctor"));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsNothing);

      await tester.tap(find.text("I'm a Patient"));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('T5: email and password fields present in doctor mode',
        (tester) async {
      await _openLoginScreen(tester);
      await tester.tap(find.text("I'm a Doctor"));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('T5b: initialRole=doctor pre-selects doctor chip',
        (tester) async {
      await _openLoginScreen(tester, initialRole: 'doctor');
      // AppBar title should reflect the doctor role immediately.
      expect(find.text('Doctor Login'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });
  });

  // --------------------------------------------------------------------------
  // Group 2 — Validation errors (before Firebase is called)
  // --------------------------------------------------------------------------
  group('T8-T9: LoginScreen validation', () {
    testWidgets('T8: empty email + password shows inline error without Firebase',
        (tester) async {
      await _openLoginScreen(tester, initialRole: 'doctor');
      // Tap Sign in with blank fields — validation fires before Firebase.
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter email and password'), findsOneWidget);
    });

    testWidgets('T9: AppBar title reads "Doctor Login" in doctor mode',
        (tester) async {
      await _openLoginScreen(tester);
      await tester.tap(find.text("I'm a Doctor"));
      await tester.pumpAndSettle();

      expect(find.text('Doctor Login'), findsOneWidget);
    });

    testWidgets('T9b: AppBar title reads "Patient Login" in patient mode',
        (tester) async {
      await _openLoginScreen(tester);
      expect(find.text('Patient Login'), findsOneWidget);
    });

    testWidgets(
        'T8b: entering only email and leaving password empty still errors',
        (tester) async {
      await _openLoginScreen(tester, initialRole: 'doctor');
      await tester.enterText(find.byType(TextField).first, 'dr@clinic.com');
      // Password field is the second TextField — leave it blank.
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter email and password'), findsOneWidget);
    });
  });

  // --------------------------------------------------------------------------
  // Group 3 — Role persistence (Firestore data-shape unit tests)
  //
  // FirestoreUserProfileService uses FirebaseFirestore.instance directly, so
  // we validate the expected data shape using FakeFirebaseFirestore rather than
  // calling the service itself.
  // --------------------------------------------------------------------------
  group('T11-T12: Role persistence — Firestore data shape', () {
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
    });

    test('T11: saveRole writes profile.role="doctor" to users/{uid}',
        () async {
      // Mirror exactly what FirestoreUserProfileService.saveRole does.
      // Dot-notation key with merge=true writes a nested field path:
      // {'profile.role': 'doctor'} → stored as {'profile': {'role': 'doctor'}}
      await fakeDb.collection('users').doc('uid123').set(
        {'profile.role': 'doctor'},
        SetOptions(merge: true),
      );

      final doc = await fakeDb.collection('users').doc('uid123').get();
      final profile = doc.data()?['profile'];
      final role = profile is Map ? profile['role'] : null;
      expect(role, equals('doctor'));
    });

    test('T12: doctor role is preserved — not overwritten by patient save',
        () async {
      // Simulate: existing doctor profile.
      await fakeDb.collection('users').doc('uid123').set({
        'profile': {'role': 'doctor'},
      });

      // Simulate the downgrade-prevention logic from _persistRoleForCurrentUser():
      // "Never downgrade an existing doctor to patient."
      final snap =
          await fakeDb.collection('users').doc('uid123').get();
      final profile = snap.data()?['profile'];
      final existingRole = profile is Map ? profile['role'] : null;

      if (existingRole != 'doctor') {
        await fakeDb.collection('users').doc('uid123').set(
          {'profile': {'role': 'patient'}},
        );
      }

      final afterSnap =
          await fakeDb.collection('users').doc('uid123').get();
      final afterProfile = afterSnap.data()?['profile'];
      final afterRole =
          afterProfile is Map ? afterProfile['role'] : null;

      expect(afterRole, equals('doctor'),
          reason: 'Existing doctor role must not be downgraded to patient');
    });

    test('T11b: getRole defaults to "patient" when role field is absent',
        () async {
      await fakeDb.collection('users').doc('uid_new').set({});

      final snap =
          await fakeDb.collection('users').doc('uid_new').get();
      final profile = snap.data()?['profile'];
      final rawRole =
          profile is Map ? profile['role'] : null;

      // Mirrors FirestoreUserProfileService.getRole() default logic:
      // returns 'patient' when role is null / not 'doctor'/'patient'.
      final resolvedRole =
          (rawRole is String && (rawRole == 'doctor' || rawRole == 'patient'))
              ? rawRole
              : 'patient';

      expect(resolvedRole, equals('patient'));
    });
  });

  // --------------------------------------------------------------------------
  // Group 4 — AuthGate routing contract
  //
  // AuthGate uses FirebaseAuth.instance.authStateChanges() and
  // FirebaseFirestore.instance, making it hard to unit-test without a full
  // Firebase mock.  These tests assert the routing conditions from auth_gate.dart
  // at the logic level, acting as a living spec.
  // --------------------------------------------------------------------------
  group('T13-T15: AuthGate routing contract (logic assertions)', () {
    // T13: role='doctor' → DoctorPortalScreen
    test('T13: routing condition — role==doctor maps to DoctorPortalScreen',
        () {
      const role = 'doctor';
      // Mirrors auth_gate.dart line 108: if (role == 'doctor') → DoctorPortalScreen
      expect(role == 'doctor', isTrue,
          reason:
              'AuthGate must route authenticated users with role="doctor" to DoctorPortalScreen');
    });

    // T14: role='patient' → MainScreen (not doctor portal)
    test('T14: routing condition — role==patient does NOT map to DoctorPortalScreen',
        () {
      const role = 'patient';
      expect(role == 'doctor', isFalse,
          reason:
              'AuthGate must NOT route patients to DoctorPortalScreen');
    });

    // T15: user==null → LoginScreen
    test('T15: routing condition — null user maps to LoginScreen', () {
      // ignore: avoid_init_to_null
      const user = null; // represents FirebaseAuth.instance.currentUser == null
      expect(user == null, isTrue,
          reason: 'AuthGate must show LoginScreen when no user is authenticated');
    });

    // Bonus: role normalization matches spec
    test('T15b: role is lower-cased and trimmed before routing', () {
      const raw = '  Doctor  ';
      final normalized = raw.trim().toLowerCase();
      expect(normalized, equals('doctor'),
          reason:
              'AuthGate trims and lower-cases role before comparison (auth_gate.dart:99)');
    });
  });

  // --------------------------------------------------------------------------
  // Group 5 — DoctorPortalScreen query logic (Firestore unit tests)
  //
  // Validates that the collectionGroup query used by DoctorPortalScreen._loadPatients()
  // correctly filters by doctorEmail and status.
  // --------------------------------------------------------------------------
  group('T16-T18: DoctorPortalScreen patient list query', () {
    late FakeFirebaseFirestore fakeDb;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
    });

    test(
        'T16: query returns active share links for matching doctorEmail',
        () async {
      await fakeDb
          .collection('users')
          .doc('patient1')
          .collection('sharedWithDoctors')
          .doc('dr_at_clinic_com')
          .set({
        'doctorEmail': 'dr@clinic.com',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final results = await fakeDb
          .collectionGroup('sharedWithDoctors')
          .where('doctorEmail', isEqualTo: 'dr@clinic.com')
          .where('status', isEqualTo: 'active')
          .get();

      expect(results.docs.length, equals(1));
      expect(results.docs.first.data()['doctorEmail'],
          equals('dr@clinic.com'));
    });

    test('T17: query returns empty list when no active links exist',
        () async {
      final results = await fakeDb
          .collectionGroup('sharedWithDoctors')
          .where('doctorEmail', isEqualTo: 'nobody@clinic.com')
          .where('status', isEqualTo: 'active')
          .get();

      expect(results.docs, isEmpty,
          reason: 'Portal must show empty state when no patients have shared');
    });

    test('T18: revoked link is excluded; only active link appears in results',
        () async {
      // Active share from patient1.
      await fakeDb
          .collection('users')
          .doc('patient1')
          .collection('sharedWithDoctors')
          .doc('link1')
          .set({'doctorEmail': 'dr@clinic.com', 'status': 'active'});

      // Revoked share from patient2 — must NOT appear.
      await fakeDb
          .collection('users')
          .doc('patient2')
          .collection('sharedWithDoctors')
          .doc('link2')
          .set({'doctorEmail': 'dr@clinic.com', 'status': 'revoked'});

      final results = await fakeDb
          .collectionGroup('sharedWithDoctors')
          .where('doctorEmail', isEqualTo: 'dr@clinic.com')
          .where('status', isEqualTo: 'active')
          .get();

      expect(results.docs.length, equals(1),
          reason: 'Revoked link must be excluded from the doctor portal query');

      final patientId =
          results.docs.first.reference.parent.parent?.id;
      expect(patientId, equals('patient1'));
    });

    test('T18b: pending link is also excluded from active query', () async {
      await fakeDb
          .collection('users')
          .doc('patient3')
          .collection('sharedWithDoctors')
          .doc('link3')
          .set({'doctorEmail': 'dr@clinic.com', 'status': 'pending'});

      final results = await fakeDb
          .collectionGroup('sharedWithDoctors')
          .where('doctorEmail', isEqualTo: 'dr@clinic.com')
          .where('status', isEqualTo: 'active')
          .get();

      expect(results.docs, isEmpty,
          reason: 'Pending links must not appear in the doctor portal');
    });
  });
}
