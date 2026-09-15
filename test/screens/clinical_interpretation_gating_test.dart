import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dhealth/config/feature_flags.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/screens/insights/trigger_correlations_screen.dart';
import 'package:dhealth/screens/insights_screen.dart';
import 'package:dhealth/screens/main_screen.dart';
import 'package:dhealth/screens/recommendations_screen.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/widgets/emergency_red_flag_modal.dart';
import 'package:dhealth/widgets/feature_flags_scope.dart';
import 'package:dhealth/widgets/urgent_red_flag_banner.dart';

Widget _app(FeatureFlags flags, Widget home) {
  return MaterialApp(
    home: FeatureFlagsScope(flags: flags, child: home),
  );
}

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

DailyLog _todayLog({
  required int itch,
  required int mood,
  bool sleepDisruption = false,
}) {
  return DailyLog(
    id: 'today-log',
    date: DateTime.now(),
    condition: 'psoriasis',
    mood: mood,
    itchIntensity: itch,
    stressLevel: 3,
    lesionSeverity: 'mild',
    affectedAreas: const ['arm'],
    sleepQuality: 4,
    sleepDisruption: sleepDisruption,
    notes: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'onboarding_condition': 'psoriasis',
    });
    DailyLogService().clearAllLogs();
  });

  group('Recommendations tab', () {
    testWidgets('EmptyState copy when showRecommendations is false',
        (tester) async {
      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults,
          const RecommendationsScreen(selectedCondition: 'psoriasis'),
        ),
      );
      await tester.pump();

      expect(find.text('Recommendations paused'), findsOneWidget);
      expect(
        find.text(
          'We\'re completing a clinical safety review before showing personalized care suggestions. Your daily logs, questionnaires, and reports to your dermatologist are unchanged.',
        ),
        findsOneWidget,
      );
      expect(find.text('📋'), findsOneWidget);
      expect(find.text('Self-Care'), findsNothing);
      await tester.ensureVisible(find.text('When to Seek Urgent Care'));
      expect(find.text('When to Seek Urgent Care'), findsOneWidget);
    });

    testWidgets('recommendation list shows when showRecommendations is true',
        (tester) async {
      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults.copyWith(showRecommendations: true),
          const RecommendationsScreen(selectedCondition: 'psoriasis'),
        ),
      );
      await tester.pump();

      expect(find.text('Recommendations paused'), findsNothing);
      expect(find.text('Self-Care'), findsOneWidget);
      expect(find.text('When to Seek Urgent Care'), findsOneWidget);
    });
  });

  group('showRiskScore', () {
    testWidgets('hides today risk card and RecentLogsList chip', (tester) async {
      DailyLogService().addLog(_todayLog(itch: 4, mood: 4));

      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults.copyWith(showRiskScore: false),
          const MainScreen(),
        ),
      );
      await _pumpUntilFound(tester, find.text('Start Daily Check-In'));

      expect(find.text("Today's Risk Score"), findsNothing);
      expect(find.textContaining('Risk:'), findsNothing);
      expect(find.text('Avg Risk'), findsNothing);
      expect(find.text('Improving'), findsNothing);
      expect(find.text('Worsening'), findsNothing);
      expect(find.text('No log for today yet'), findsNothing);
    });
  });

  group('showRedFlags', () {
    testWidgets('skips UrgentRedFlagBanner and EmergencyRedFlagModal',
        (tester) async {
      DailyLogService().addLog(
        _todayLog(itch: 9, mood: 1, sleepDisruption: true),
      );

      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults.copyWith(showRedFlags: false),
          const MainScreen(),
        ),
      );
      await _pumpUntilFound(tester, find.text('Start Daily Check-In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(UrgentRedFlagBanner), findsNothing);
      expect(find.byType(EmergencyRedFlagModal), findsNothing);
    });

    testWidgets('hides insights detectRedFlags section', (tester) async {
      final logs = DailyLogService();
      logs.addLog(_todayLog(itch: 9, mood: 1, sleepDisruption: true));

      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults.copyWith(showRedFlags: false),
          InsightsScreen(dailyLogService: logs, condition: 'psoriasis'),
        ),
      );
      await _pumpUntilFound(tester, find.text('Overall Health Score'));

      expect(find.textContaining('Red Flags'), findsNothing);
    });
  });

  group('showTriggerInsights', () {
    testWidgets('TriggerCorrelationsScreen shows paused EmptyState',
        (tester) async {
      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults.copyWith(showTriggerInsights: false),
          TriggerCorrelationsScreen(
            logs: const [],
            pros: const <ProAssessment>[],
            condition: 'psoriasis',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Trigger insights paused'), findsOneWidget);
      expect(
        find.textContaining('personalized trigger patterns'),
        findsOneWidget,
      );
    });
  });
}
