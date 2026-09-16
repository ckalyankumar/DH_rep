import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dhealth/screens/daily_log_screen.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/widgets/mood_selector_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    DailyLogService().clearAllLogs();
  });

  Future<void> pumpDailyLog(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DailyLogScreen(
        dailyLogService: DailyLogService(),
        condition: 'psoriasis',
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('opening DailyLogScreen without edits does not write a log',
      (tester) async {
    await pumpDailyLog(tester);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(DailyLogService().getLogs(), isEmpty);
  });

  testWidgets('opening with an existing today log does not write again',
      (tester) async {
    DailyLogService().createAndAdd(
      condition: 'psoriasis',
      mood: 4,
      itchIntensity: 2,
      stressLevel: 3,
      lesionSeverity: 'mild',
      affectedAreas: const ['Arms'],
      sleepQuality: 4,
      sleepDisruption: false,
      notes: 'seeded',
      date: DateTime.now(),
    );
    final idBefore = DailyLogService().getTodayLog()!.id;
    final countBefore = DailyLogService().getRawLogs().length;

    await pumpDailyLog(tester);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(DailyLogService().getTodayLog()!.id, idBefore);
    expect(DailyLogService().getRawLogs().length, countBefore);
  });

  testWidgets('a genuine field edit still saves after the debounce delay',
      (tester) async {
    await pumpDailyLog(tester);

    await tester.tap(find.byType(MoodSelectorOption).at(5));
    await tester.pump();
    expect(DailyLogService().getLogs(), isEmpty);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(DailyLogService().getLogs(), isNotEmpty);
    expect(DailyLogService().getTodayLog()!.mood, 6);
  });

  testWidgets(
      'starting a fresh check-in does not write unchanged defaults',
      (tester) async {
    DailyLogService().createAndAdd(
      condition: 'psoriasis',
      mood: 4,
      itchIntensity: 2,
      stressLevel: 3,
      lesionSeverity: 'mild',
      affectedAreas: const ['Arms'],
      sleepQuality: 4,
      sleepDisruption: false,
      notes: 'seeded',
      date: DateTime.now(),
    );
    final idBefore = DailyLogService().getTodayLog()!.id;
    final countBefore = DailyLogService().getRawLogs().length;

    await pumpDailyLog(tester);
    await tester.ensureVisible(find.text('Start a new check-in'));
    await tester.tap(find.text('Start a new check-in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 1600));

    expect(DailyLogService().getTodayLog()!.id, idBefore);
    expect(DailyLogService().getRawLogs().length, countBefore);
  });
}
