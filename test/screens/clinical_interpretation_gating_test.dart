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
import 'package:dhealth/widgets/trigger_insight_card.dart';
import 'package:dhealth/widgets/urgent_red_flag_banner.dart';

/// Every interpretive feature enabled. Single-flag tests start from here and
/// switch one flag off, so they isolate that flag instead of relying on the
/// (now all-false) defaults.
const _allOn = FeatureFlags(
  showRiskScore: true,
  showRedFlags: true,
  showTriggerInsights: true,
  showRecommendations: true,
);

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

/// 20 days with a perfect stress–itch relationship, so InsightEngine detects
/// 'Psychological Stress' and the flare-risk card has non-empty topTriggers.
void _seedStressItchLogs(DailyLogService service) {
  final today = DateTime.now();
  for (var i = 0; i < 20; i++) {
    service.addLog(
      DailyLog(
        id: 'stress-itch-$i',
        date: DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: i)),
        condition: 'psoriasis',
        mood: 4,
        itchIntensity: i.isEven ? 8 : 2,
        stressLevel: i.isEven ? 9 : 1,
        lesionSeverity: 'mild',
        affectedAreas: const ['arm'],
        sleepQuality: 4,
        sleepDisruption: false,
        notes: '',
      ),
    );
  }
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
          _allOn.copyWith(showRiskScore: false),
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
          _allOn.copyWith(showRedFlags: false),
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
          _allOn.copyWith(showRedFlags: false),
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
          _allOn.copyWith(showTriggerInsights: false),
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

  group('Fail-closed defaults (nothing enabled remotely)', () {
    testWidgets('home hides risk card, risk chips, avg risk, red flags, '
        'and trigger card', (tester) async {
      DailyLogService().addLog(
        _todayLog(itch: 9, mood: 1, sleepDisruption: true),
      );

      await tester.pumpWidget(
        _app(FeatureFlags.defaults, const MainScreen()),
      );
      await _pumpUntilFound(tester, find.text('Start Daily Check-In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Start Daily Check-In'), findsOneWidget);
      expect(find.text("Today's Risk Score"), findsNothing);
      expect(find.textContaining('/ 100'), findsNothing);
      expect(find.textContaining('Risk:'), findsNothing);
      expect(find.text('Avg Risk'), findsNothing);
      expect(find.byType(UrgentRedFlagBanner), findsNothing);
      expect(find.byType(EmergencyRedFlagModal), findsNothing);
      expect(find.byType(TriggerInsightCard), findsNothing);
    });

    testWidgets('insights hides health score, flare risk, red flags, and '
        'triggers', (tester) async {
      final logs = DailyLogService();
      logs.addLog(_todayLog(itch: 9, mood: 1, sleepDisruption: true));

      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults,
          InsightsScreen(dailyLogService: logs, condition: 'psoriasis'),
        ),
      );
      await _pumpUntilFound(tester, find.text('Trigger insights paused'));

      expect(find.text('Trigger insights paused'), findsOneWidget);
      expect(find.text('Overall Health Score'), findsNothing);
      expect(find.textContaining('Flare Risk'), findsNothing);
      expect(find.textContaining('Top triggers'), findsNothing);
      expect(find.textContaining('Red Flags'), findsNothing);
      expect(find.text('Your Primary Triggers'), findsNothing);
    });

    testWidgets('insights positive control: all-on shows the same surfaces',
        (tester) async {
      final logs = DailyLogService();
      logs.addLog(_todayLog(itch: 9, mood: 1, sleepDisruption: true));

      await tester.pumpWidget(
        _app(
          _allOn,
          InsightsScreen(dailyLogService: logs, condition: 'psoriasis'),
        ),
      );
      await _pumpUntilFound(tester, find.text('Overall Health Score'));

      expect(find.text('Overall Health Score'), findsOneWidget);
      expect(find.textContaining('Flare Risk'), findsOneWidget);
      expect(find.text('Trigger insights paused'), findsNothing);
    });

    testWidgets('trigger correlations screen shows paused EmptyState',
        (tester) async {
      await tester.pumpWidget(
        _app(
          FeatureFlags.defaults,
          TriggerCorrelationsScreen(
            logs: const [],
            pros: const <ProAssessment>[],
            condition: 'psoriasis',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Trigger insights paused'), findsOneWidget);
      expect(find.byType(TriggerInsightCard), findsNothing);
    });

    testWidgets('recommendations with no FeatureFlagsScope in the tree stay '
        'paused; urgent-care content still shows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecommendationsScreen(selectedCondition: 'psoriasis'),
        ),
      );
      await tester.pump();

      expect(find.text('Recommendations paused'), findsOneWidget);
      expect(find.text('Self-Care'), findsNothing);
      expect(find.byTooltip('Export for dermatologist review'), findsNothing);
      await tester.ensureVisible(find.text('When to Seek Urgent Care'));
      expect(find.text('When to Seek Urgent Care'), findsOneWidget);
    });
  });

  group('Flare-risk card "Top triggers" line', () {
    testWidgets('positive control: risk on + triggers on shows Top triggers',
        (tester) async {
      final logs = DailyLogService();
      _seedStressItchLogs(logs);

      await tester.pumpWidget(
        _app(
          _allOn,
          InsightsScreen(dailyLogService: logs, condition: 'psoriasis'),
        ),
      );
      await _pumpUntilFound(tester, find.textContaining('Top triggers'));

      expect(find.textContaining('Top triggers'), findsOneWidget);
    });

    testWidgets('risk on + triggers off hides Top triggers, keeps flare risk',
        (tester) async {
      final logs = DailyLogService();
      _seedStressItchLogs(logs);

      await tester.pumpWidget(
        _app(
          _allOn.copyWith(showTriggerInsights: false),
          InsightsScreen(dailyLogService: logs, condition: 'psoriasis'),
        ),
      );
      await _pumpUntilFound(tester, find.textContaining('Flare Risk'));

      expect(find.textContaining('Flare Risk'), findsOneWidget);
      expect(find.textContaining('Top triggers'), findsNothing);
      expect(find.textContaining('Psychological Stress'), findsNothing);
    });
  });
}
