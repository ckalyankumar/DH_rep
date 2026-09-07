// Patient-shell flow tests.
//
// `pubspec.yaml` does not include the `integration_test` package, and this
// file lives under `test/` (not `integration_test/`), so it runs with
// `flutter test` — not device-based `flutter test integration_test`.
// Granular AuthGate / MainScreen / DoctorPortal checks live in widget_test.dart.

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

  group('App shell flows', () {
    testWidgets('unauthenticated launch lands on patient login', (tester) async {
      await tester.pumpWidget(
        _app(AuthGate(authStateChanges: Stream<User?>.value(null))),
      );
      await _pumpUntilFound(tester, find.byType(LoginScreen));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('patient home tabs: Home → Insights → Recommendations',
        (tester) async {
      await tester.pumpWidget(_app(const MainScreen()));
      await _pumpUntilFound(tester, find.text('Start Daily Check-In'));

      expect(find.text('Select Your Condition'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);

      await tester.tap(find.text('Insights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Create at least 10 daily logs to generate insights'),
        findsOneWidget,
      );

      await tester.tap(find.text('Recommendations'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.widgetWithText(AppBar, 'Recommendations'), findsOneWidget);
      expect(find.text('Self-Care'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Start Daily Check-In'), findsOneWidget);
    });

    testWidgets('doctor portal lists only active shares from fake Firestore',
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
      expect(find.text('Your Patients'), findsOneWidget);
    });
  });
}
