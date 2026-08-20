import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhealth/app.dart';

void main() {
  group('DHealth Integration Tests', () {
    testWidgets('App launches successfully',
        (WidgetTester tester) async {
      // Build our app and trigger a frame
      await tester.pumpWidget(const DermCareApp());

      // Verify app title is present
      expect(find.text('DHealth'), findsWidgets);

      // Verify navigation buttons exist
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Daily Log'), findsWidgets);
      expect(find.text('Predictions'), findsWidgets);
      expect(find.text('Recommendations'), findsWidgets);
    });

    testWidgets('Dashboard screen renders',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Dashboard should be active by default
      expect(find.text('Select Your Condition'), findsOneWidget);

      // Dashboard cards should be visible
      expect(find.text('Flare Risk Prediction'), findsOneWidget);
      expect(find.text('Severity Trends'), findsOneWidget);
      expect(find.text('Active Recommendations'), findsOneWidget);
    });

    testWidgets('Navigation to Daily Log works',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Tap Daily Log button
      await tester.tap(find.text('Daily Log'));
      await tester.pumpAndSettle();

      // Verify Daily Log screen
      expect(find.text('Daily Symptom Check-In'), findsOneWidget);
    });

    testWidgets('Navigation to Predictions works',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Tap Predictions button
      await tester.tap(find.text('Predictions'));
      await tester.pumpAndSettle();

      // Verify Predictions screen
      expect(find.text('Flare Risk Analysis'), findsOneWidget);
    });

    testWidgets('Navigation to Recommendations works',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Tap Recommendations button
      await tester.tap(find.text('Recommendations'));
      await tester.pumpAndSettle();

      // Verify Recommendations screen
      expect(find.text('Personalized Recommendations'), findsOneWidget);
    });

    testWidgets('Condition selector switches between conditions',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Verify initial condition data loads
      expect(find.text('64%'), findsOneWidget); // Psoriasis risk

      // Open dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Select Eczema
      await tester.tap(find.text('Atopic Dermatitis (Eczema)').last);
      await tester.pumpAndSettle();

      // Verify new condition data (58% for eczema)
      expect(find.text('58%'), findsOneWidget);
    });

    testWidgets('Daily Log form has all required fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Navigate to Daily Log
      await tester.tap(find.text('Daily Log'));
      await tester.pumpAndSettle();

      // Verify form sections
      expect(find.text('How are you feeling today?'), findsOneWidget);
      expect(find.text('Symptom Severity'), findsOneWidget);
      expect(find.text('Visible Lesions/Rash'), findsOneWidget);
      expect(find.text('Sleep Quality'), findsOneWidget);
      expect(find.text('Additional Notes (Optional)'), findsOneWidget);

      // Verify buttons
      expect(find.text('Save Today\'s Log'), findsOneWidget);
      expect(find.text('Clear Form'), findsOneWidget);
    });

    testWidgets('Mood emoji selector works',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Navigate to Daily Log
      await tester.tap(find.text('Daily Log'));
      await tester.pumpAndSettle();

      // Find and tap Great mood (😄)
      await tester.tap(find.text('😄'));
      await tester.pumpAndSettle();

      // Verify it's selected (mood should update)
      expect(find.text('😄'), findsOneWidget);
    });

    testWidgets('Sliders update values on interaction',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Navigate to Daily Log
      await tester.tap(find.text('Daily Log'));
      await tester.pumpAndSettle();

      // Find itch intensity slider
      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);

      // Drag first slider
      await tester.drag(sliders.first, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Value should have changed
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('Recommendations detail screen expands',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Navigate to Recommendations
      await tester.tap(find.text('Recommendations'));
      await tester.pumpAndSettle();

      // Verify recommendation cards exist
      expect(
        find.text('Implement Stress Management Routine'),
        findsOneWidget,
      );

      // Tap first recommendation
      await tester.tap(find.text('Implement Stress Management Routine'));
      await tester.pumpAndSettle();

      // Verify detail screen
      expect(find.text('Why This Matters'), findsOneWidget);
      expect(find.text('How to Implement'), findsOneWidget);
      expect(find.text('Expected Benefits'), findsOneWidget);
    });

    testWidgets('Back navigation works from all screens',
        (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Go to Predictions
      await tester.tap(find.text('Predictions'));
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.text('← Back to Dashboard'));
      await tester.pumpAndSettle();

      // Should be back at Dashboard
      expect(find.text('Select Your Condition'), findsOneWidget);
    });
  });
}
