// Widget tests for the live app shell (AuthGate / MainScreen / DoctorPortal).
//
// LoginScreen role chips, validation, and role-persistence data shape are
// covered in `doctor_login_test.dart` (Groups 1–3) and are not duplicated here.
//
// Firebase is not initialized. AuthGate and DoctorPortalScreen are tested via
// injected fakes (`authStateChanges`, FakeFirebaseFirestore), matching the
// doctor_login_test.dart approach.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dhealth/screens/doctor_portal_screen.dart';
import 'package:dhealth/screens/login_screen.dart';
import 'package:dhealth/screens/main_screen.dart';
import 'package:dhealth/widgets/auth_gate.dart';

Widget _app(Widget home) => MaterialApp(home: home);

/// Advance frames until [finder] appears, without waiting on infinite spinners.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'onboarding_condition': 'psoriasis',
    });
  });

  group('AuthGate routing', () {
    testWidgets('signed-out session shows LoginScreen', (tester) async {
      await tester.pumpWidget(
        _app(AuthGate(authStateChanges: Stream<User?>.value(null))),
      );
      await _pumpUntilFound(tester, find.byType(LoginScreen));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Patient Login'), findsOneWidget);
      expect(find.text("I'm a Patient"), findsOneWidget);
      expect(find.text("I'm a Doctor"), findsOneWidget);
    });

    test('roleFromUserProfile: doctor → DoctorPortalScreen destination', () {
      expect(
        roleFromUserProfile({
          'profile': {'role': 'doctor'},
        }),
        'doctor',
      );
    });

    test('roleFromUserProfile: patient does not map to doctor', () {
      expect(
        roleFromUserProfile({
          'profile': {'role': 'patient'},
        }),
        'patient',
      );
    });

    test('roleFromUserProfile: missing/invalid role defaults to patient', () {
      expect(roleFromUserProfile(null), 'patient');
      expect(roleFromUserProfile({}), 'patient');
      expect(
        roleFromUserProfile({
          'profile': {'role': 'admin'},
        }),
        'patient',
      );
    });

    test('roleFromUserProfile trims and lower-cases before routing', () {
      expect(
        roleFromUserProfile({
          'profile': {'role': '  Doctor  '},
        }),
        'doctor',
      );
    });
  });

  group('MainScreen patient home', () {
    testWidgets('renders condition selector, dashboard, check-in, and tabs',
        (tester) async {
      await tester.pumpWidget(_app(const MainScreen()));
      await _pumpUntilFound(tester, find.text('Start Daily Check-In'));

      expect(find.text('DHealth'), findsWidgets);
      expect(find.text('Select Your Condition'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('No log for today yet'), findsOneWidget);
      expect(find.text("Create Today's Log"), findsOneWidget);
      expect(find.text('Start Daily Check-In'), findsOneWidget);
      expect(find.text('Daily Symptom Log'), findsOneWidget);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);

      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('Recommendations tab opens RecommendationsScreen',
        (tester) async {
      await tester.pumpWidget(_app(const MainScreen()));
      await _pumpUntilFound(tester, find.text('Start Daily Check-In'));

      await tester.tap(find.text('Recommendations'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.widgetWithText(AppBar, 'Recommendations'), findsOneWidget);
      expect(find.text('Self-Care'), findsOneWidget);
      expect(find.text('Discuss with Doctor'), findsOneWidget);
    });
  });

  group('DoctorPortalScreen', () {
    testWidgets('no doctor session shows sign-in prompt', (tester) async {
      await tester.pumpWidget(
        _app(DoctorPortalScreen(firestore: FakeFirebaseFirestore())),
      );
      await tester.pump();

      expect(find.text('Your Patients'), findsOneWidget);
      expect(
        find.text('Sign in as a doctor to view patients.'),
        findsOneWidget,
      );
    });

    testWidgets('doctor session with no shares shows empty state',
        (tester) async {
      await tester.pumpWidget(
        _app(
          DoctorPortalScreen(
            firestore: FakeFirebaseFirestore(),
            doctorEmail: 'dr@clinic.com',
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('No patients yet'));

      expect(find.text('No patients yet'), findsOneWidget);
      expect(
        find.text(
          'Patients will appear here once they share their data with you from the dHealth app.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Read-only · You can only see patients who have shared access with you.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('seeded active share shows patient name and actions',
        (tester) async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb
          .collection('doctorLinks')
          .doc('dr_at_clinic_com')
          .collection('patients')
          .doc('patient1')
          .set({
        'patientId': 'patient1',
        'status': 'active',
      });
      await fakeDb.collection('users').doc('patient1').set({
        'profile': {'displayName': 'Ada Patient'},
      });
      await fakeDb
          .collection('doctorLinks')
          .doc('dr_at_clinic_com')
          .collection('patients')
          .doc('patient2')
          .set({
        'patientId': 'patient2',
        'status': 'revoked',
      });

      await tester.pumpWidget(
        _app(
          DoctorPortalScreen(
            firestore: fakeDb,
            doctorEmail: 'dr@clinic.com',
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('Ada Patient'));

      expect(find.text('Ada Patient'), findsOneWidget);
      expect(find.text('Download Report'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('No patients yet'), findsNothing);
    });
  });
}
