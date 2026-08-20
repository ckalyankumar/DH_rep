import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhealth/app.dart';

void main() {
  group('DHealth App - Widget Tests', () {
    testWidgets('App starts and shows Dashboard', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      expect(find.text('DHealth'), findsWidgets);
      expect(find.byKey(const ValueKey('dashboardButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('dailyLogButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('predictionsButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('recommendationsButton')), findsOneWidget);
      expect(find.text('Select Your Condition'), findsOneWidget);
    });

    testWidgets('Condition selector works', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      final conditionDropdown = find.byKey(const ValueKey('conditionSelector'));
      expect(conditionDropdown, findsOneWidget);

      await tester.tap(conditionDropdown);
      await tester.pumpAndSettle();

      expect(find.text('Psoriasis'), findsWidgets);
      expect(find.text('Atopic Dermatitis (Eczema)'), findsWidgets);
    });

    testWidgets('Dashboard cards display correct data', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      expect(find.byKey(const ValueKey('flareRiskCard')), findsOneWidget);
      expect(find.byKey(const ValueKey('severityTrendsCard')), findsOneWidget);
      expect(find.byKey(const ValueKey('activeRecommendationsCard')), findsOneWidget);

      expect(find.byKey(const ValueKey('riskLevelMedium')), findsOneWidget);
      expect(find.text('64'), findsOneWidget);
      expect(find.text('12 decrease'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Navigation between screens works', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      // Tap Daily Log Button
      final dailyLogButton = find.byKey(const ValueKey('dailyLogButton'));
      expect(dailyLogButton, findsOneWidget);
      await tester.tap(dailyLogButton);
      await tester.pumpAndSettle();
      expect(find.text('Daily Symptom Check-In'), findsOneWidget);

      // Tap Predictions Button
      final predictionsButton = find.byKey(const ValueKey('predictionsButton'));
      expect(predictionsButton, findsOneWidget);
      await tester.tap(predictionsButton);
      await tester.pumpAndSettle();
      expect(find.text('Flare Risk Analysis'), findsOneWidget);

      // Tap Recommendations Button
      final recommendationsButton = find.byKey(const ValueKey('recommendationsButton'));
      expect(recommendationsButton, findsOneWidget);
      await tester.tap(recommendationsButton);
      await tester.pumpAndSettle();
      expect(find.text('Personalized Recommendations'), findsOneWidget);
    });

    testWidgets('Daily Log form elements render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      final dailyLogButton = find.byKey(const ValueKey('dailyLogButton'));
      await tester.tap(dailyLogButton);
      await tester.pumpAndSettle();

      expect(find.text('How are you feeling today?'), findsOneWidget);
      expect(find.text('Symptom Severity'), findsOneWidget);
      expect(find.text('Visible Lesions/Rash'), findsOneWidget);
      expect(find.text('Sleep Quality'), findsOneWidget);
      expect(find.text('Additional Notes (Optional)'), findsOneWidget);

      // Mood emoji selectors by key
      expect(find.byKey(const ValueKey('moodEmojiVeryBad')), findsOneWidget);
      expect(find.byKey(const ValueKey('moodEmojiBad')), findsOneWidget);
      expect(find.byKey(const ValueKey('moodEmojiNeutral')), findsOneWidget);
      expect(find.byKey(const ValueKey('moodEmojiGood')), findsOneWidget);
      expect(find.byKey(const ValueKey('moodEmojiVeryGood')), findsOneWidget);

      // Sliders
      expect(find.byType(Slider), findsWidgets);

      // Buttons
      expect(find.byKey(const ValueKey('saveTodaysLogButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('clearFormButton')), findsOneWidget);
    });

    testWidgets('Mood selector interaction works', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      final dailyLogButton = find.byKey(const ValueKey('dailyLogButton'));
      await tester.tap(dailyLogButton);
      await tester.pumpAndSettle();

      final moodEmojiGood = find.byKey(const ValueKey('moodEmojiGood'));
      expect(moodEmojiGood, findsOneWidget);

      await tester.tap(moodEmojiGood);
      await tester.pumpAndSettle();

      // Add your assertion here depending on changes expected on mood selection
    });

    testWidgets('Predictions screen displays risk factors', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      final predictionsButton = find.byKey(const ValueKey('predictionsButton'));
      await tester.tap(predictionsButton);
      await tester.pumpAndSettle();

      expect(find.text('Current Risk Level'), findsOneWidget);
      expect(find.text('Days Until Peak Risk'), findsOneWidget);
      expect(find.text('Confidence Score'), findsOneWidget);
      expect(find.text('Contributing Risk Factors'), findsOneWidget);
      expect(find.text('7-Day Risk Forecast'), findsOneWidget);
      expect(find.text('Historical Flare Timeline'), findsOneWidget);
    });

    testWidgets('Recommendations display with priority badges', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      final recommendationsButton = find.byKey(const ValueKey('recommendationsButton'));
      await tester.tap(recommendationsButton);
      await tester.pumpAndSettle();

      expect(find.text('Implement Stress Management Routine'), findsOneWidget);
      expect(find.text('Optimize Winter Skin Protection'), findsOneWidget);
      expect(find.text('Enhance Medication Timing Consistency'), findsOneWidget);

      expect(find.text('HIGH'), findsWidgets);
      expect(find.text('MEDIUM'), findsWidgets);
    });

    testWidgets('Back navigation from detail screens works', (WidgetTester tester) async {
      await tester.pumpWidget(const DermCareApp());

      final predictionsButton = find.byKey(const ValueKey('predictionsButton'));
      await tester.tap(predictionsButton);
      await tester.pumpAndSettle();

      expect(find.text('Flare Risk Analysis'), findsOneWidget);

      final backButton = find.byKey(const ValueKey('backToDashboardButton'));

      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Select Your Condition'), findsOneWidget);
    });
  });
}
