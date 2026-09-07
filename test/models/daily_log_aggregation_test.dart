import 'package:flutter_test/flutter_test.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/services/log_deduplication_service.dart';

DailyLog _log({
  required String id,
  required DateTime date,
  DateTime? createdAt,
  String condition = 'psoriasis',
  int mood = 3,
  int itch = 0,
  int stress = 3,
  String lesion = 'none',
  List<String> areas = const [],
  int sleepQuality = 3,
  bool sleepDisruption = false,
  String notes = '',
  List<String>? triggers,
  List<String>? structuredTriggerIds,
  String? treatmentNoteAction,
  String? treatmentNoteText,
}) {
  return DailyLog(
    id: id,
    date: date,
    createdAt: createdAt,
    condition: condition,
    mood: mood,
    itchIntensity: itch,
    stressLevel: stress,
    lesionSeverity: lesion,
    affectedAreas: areas,
    sleepQuality: sleepQuality,
    sleepDisruption: sleepDisruption,
    notes: notes,
    triggers: triggers,
    structuredTriggerIds: structuredTriggerIds,
    treatmentNoteAction: treatmentNoteAction,
    treatmentNoteText: treatmentNoteText,
  );
}

void main() {
  group('DailyLog.lesionSeverityRank', () {
    test('orders none < mild < moderate < severe', () {
      expect(DailyLog.lesionSeverityRank('none'), 0);
      expect(DailyLog.lesionSeverityRank('mild'), 1);
      expect(DailyLog.lesionSeverityRank('moderate'), 2);
      expect(DailyLog.lesionSeverityRank('severe'), 3);
      expect(
        DailyLog.lesionSeverityRank('none') <
            DailyLog.lesionSeverityRank('mild'),
        isTrue,
      );
      expect(
        DailyLog.lesionSeverityRank('mild') <
            DailyLog.lesionSeverityRank('moderate'),
        isTrue,
      );
      expect(
        DailyLog.lesionSeverityRank('moderate') <
            DailyLog.lesionSeverityRank('severe'),
        isTrue,
      );
    });

    test('is case-insensitive; unknown ranks with none', () {
      expect(DailyLog.lesionSeverityRank('SEVERE'), 3);
      expect(DailyLog.lesionSeverityRank(' Mild '), 1);
      expect(DailyLog.lesionSeverityRank('unknown'), 0);
      expect(DailyLog.lesionSeverityRank(''), 0);
    });
  });

  group('DailyLog.aggregateWithSameDay', () {
    final morning = DateTime(2026, 9, 7, 8);
    final evening = DateTime(2026, 9, 7, 20);

    test('takes max itch across a later separate session (12h gap)', () {
      // High itch, otherwise mild → lower calculateRiskScore than the evening log.
      final highItch = _log(
        id: 'am',
        date: morning,
        createdAt: morning,
        itch: 9,
        mood: 5,
        stress: 0,
        lesion: 'none',
        sleepQuality: 5,
      );
      final highComposite = _log(
        id: 'pm',
        date: evening,
        createdAt: evening,
        itch: 2,
        mood: 1,
        stress: 10,
        lesion: 'moderate',
        sleepQuality: 1,
        sleepDisruption: true,
        areas: const ['arm', 'leg'],
      );
      expect(
        highComposite.calculateRiskScore(),
        greaterThan(highItch.calculateRiskScore()),
      );

      final merged = DailyLog.aggregateWithSameDay(highItch, highComposite);
      expect(merged.itchIntensity, 9);
    });

    test('takes the most severe lesion across a later separate session', () {
      final mildLater = _log(
        id: 'later',
        date: evening,
        createdAt: evening,
        lesion: 'mild',
      );
      final severeEarlier = _log(
        id: 'earlier',
        date: morning,
        createdAt: morning,
        lesion: 'severe',
      );
      expect(
        DailyLog.aggregateWithSameDay(mildLater, severeEarlier).lesionSeverity,
        'severe',
      );
      expect(
        DailyLog.aggregateWithSameDay(severeEarlier, mildLater).lesionSeverity,
        'severe',
      );
      expect(
        DailyLog.aggregateWithSameDay(
          _log(id: 'a', date: morning, createdAt: morning, lesion: 'none'),
          _log(id: 'b', date: evening, createdAt: evening, lesion: 'moderate'),
        ).lesionSeverity,
        'moderate',
      );
    });

    test('uses latest mood, stress, sleepQuality, and sleepDisruption', () {
      final am = _log(
        id: 'am',
        date: morning,
        createdAt: morning,
        mood: 2,
        stress: 8,
        sleepQuality: 1,
        sleepDisruption: true,
      );
      final pm = _log(
        id: 'pm',
        date: evening,
        createdAt: evening,
        mood: 4,
        stress: 3,
        sleepQuality: 5,
        sleepDisruption: false,
      );

      final merged = DailyLog.aggregateWithSameDay(am, pm);
      expect(merged.mood, 4);
      expect(merged.stressLevel, 3);
      expect(merged.sleepQuality, 5);
      expect(merged.sleepDisruption, isFalse);

      // Incoming-older must not be treated as "latest" by argument order.
      final reversed = DailyLog.aggregateWithSameDay(pm, am);
      expect(reversed.mood, 4);
      expect(reversed.stressLevel, 3);
      expect(reversed.sleepQuality, 5);
      expect(reversed.sleepDisruption, isFalse);
    });

    test('unions affected areas, triggers, and structuredTriggerIds', () {
      final am = _log(
        id: 'am',
        date: morning,
        createdAt: morning,
        areas: const ['scalp'],
        triggers: const ['stress'],
        structuredTriggerIds: const ['stress.work'],
      );
      final pm = _log(
        id: 'pm',
        date: evening,
        createdAt: evening,
        areas: const ['scalp', 'elbows'],
        triggers: const ['cold'],
        structuredTriggerIds: const ['env.cold'],
      );
      final merged = DailyLog.aggregateWithSameDay(am, pm);
      expect(merged.affectedAreas, ['scalp', 'elbows']);
      expect(merged.triggers, ['stress', 'cold']);
      expect(merged.structuredTriggerIds, ['stress.work', 'env.cold']);
    });

    test('notes: latest saved note replaces the earlier one', () {
      final am = _log(
        id: 'am',
        date: morning,
        createdAt: morning,
        notes: 'Morning spike',
      );
      final pm = _log(
        id: 'pm',
        date: evening,
        createdAt: evening,
        notes: 'Eased after shower',
      );
      expect(
        DailyLog.aggregateWithSameDay(am, pm).notes,
        'Eased after shower',
      );
      expect(
        DailyLog.aggregateWithSameDay(pm, am).notes,
        'Eased after shower',
      );
    });

    test('itch: within 2h takes latest, even if lower', () {
      final t0 = DateTime(2026, 9, 7, 9);
      final t30 = t0.add(const Duration(minutes: 30));
      final highThenLow = DailyLog.aggregateWithSameDay(
        _log(id: 'a', date: t0, createdAt: t0, itch: 9),
        _log(id: 'b', date: t30, createdAt: t30, itch: 2),
      );
      expect(highThenLow.itchIntensity, 2);

      final reversed = DailyLog.aggregateWithSameDay(
        _log(id: 'b', date: t30, createdAt: t30, itch: 2),
        _log(id: 'a', date: t0, createdAt: t0, itch: 9),
      );
      expect(reversed.itchIntensity, 2);
    });

    test('itch: 3h apart takes max', () {
      final t0 = DateTime(2026, 9, 7, 9);
      final t3h = t0.add(const Duration(hours: 3));
      expect(
        DailyLog.aggregateWithSameDay(
          _log(id: 'a', date: t0, createdAt: t0, itch: 2),
          _log(id: 'b', date: t3h, createdAt: t3h, itch: 8),
        ).itchIntensity,
        8,
      );
      expect(
        DailyLog.aggregateWithSameDay(
          _log(id: 'a', date: t0, createdAt: t0, itch: 8),
          _log(id: 'b', date: t3h, createdAt: t3h, itch: 2),
        ).itchIntensity,
        8,
      );
    });

    test('lesion: within 2h takes latest; 3h apart takes most severe', () {
      final t0 = DateTime(2026, 9, 7, 9);
      final t30 = t0.add(const Duration(minutes: 30));
      final t3h = t0.add(const Duration(hours: 3));

      expect(
        DailyLog.aggregateWithSameDay(
          _log(id: 'a', date: t0, createdAt: t0, lesion: 'severe'),
          _log(id: 'b', date: t30, createdAt: t30, lesion: 'mild'),
        ).lesionSeverity,
        'mild',
      );
      expect(
        DailyLog.aggregateWithSameDay(
          _log(id: 'a', date: t0, createdAt: t0, lesion: 'mild'),
          _log(id: 'b', date: t3h, createdAt: t3h, lesion: 'severe'),
        ).lesionSeverity,
        'severe',
      );
      expect(
        DailyLog.aggregateWithSameDay(
          _log(id: 'a', date: t0, createdAt: t0, lesion: 'severe'),
          _log(id: 'b', date: t3h, createdAt: t3h, lesion: 'mild'),
        ).lesionSeverity,
        'severe',
      );
    });

    test('itch: three readings fold chronologically against last prior entry',
        () {
      final t0 = DateTime(2026, 9, 7, 9);
      final t15 = t0.add(const Duration(minutes: 15));
      final t4h = t15.add(const Duration(hours: 4));
      final merged = DailyLog.aggregateAll([
        _log(id: 'c', date: t4h, createdAt: t4h, itch: 1),
        _log(id: 'a', date: t0, createdAt: t0, itch: 9),
        _log(id: 'b', date: t15, createdAt: t15, itch: 2),
      ]);
      // 9:00(9) + 9:15(2) → latest 2; 4h later (1) → max(2, 1) = 2
      expect(merged.itchIntensity, 2);
      expect(merged.id, 'a');
    });

    test('lesion: three readings fold chronologically against last prior entry',
        () {
      final t0 = DateTime(2026, 9, 7, 9);
      final t15 = t0.add(const Duration(minutes: 15));
      final t4h = t15.add(const Duration(hours: 4));
      final merged = DailyLog.aggregateAll([
        _log(id: 'c', date: t4h, createdAt: t4h, lesion: 'none'),
        _log(id: 'a', date: t0, createdAt: t0, lesion: 'severe'),
        _log(id: 'b', date: t15, createdAt: t15, lesion: 'mild'),
      ]);
      // severe + 15min mild → latest mild; 4h none → max(mild, none) = mild
      expect(merged.lesionSeverity, 'mild');
    });

    test('itch: window is vs most recent prior, not first-created', () {
      // 9:00 itch 5, 10:50 itch 9 (1h50 latest=9), 12:40 itch 3 (1h50 after 10:50).
      // Correct: latest 3. If compared to 9:00 (3h40) would wrongly MAX to 9.
      final t0 = DateTime(2026, 9, 7, 9);
      final t110 = t0.add(const Duration(hours: 1, minutes: 50));
      final t240 = t110.add(const Duration(hours: 1, minutes: 50));
      final merged = DailyLog.aggregateAll([
        _log(id: 'a', date: t0, createdAt: t0, itch: 5),
        _log(id: 'b', date: t110, createdAt: t110, itch: 9),
        _log(id: 'c', date: t240, createdAt: t240, itch: 3),
      ]);
      expect(merged.itchIntensity, 3);
    });

    test('keeps first-created id and createdAt; latest treatment note', () {
      final am = _log(
        id: 'first-id',
        date: morning,
        createdAt: morning,
        treatmentNoteAction: 'allGood',
        treatmentNoteText: 'ok',
      );
      final pm = _log(
        id: 'second-id',
        date: evening,
        createdAt: evening,
        treatmentNoteAction: 'missedDose',
        treatmentNoteText: 'skipped PM',
      );
      final merged = DailyLog.aggregateWithSameDay(am, pm);
      expect(merged.id, 'first-id');
      expect(merged.createdAt, morning);
      expect(merged.date, evening);
      expect(merged.treatmentNoteAction, 'missedDose');
      expect(merged.treatmentNoteText, 'skipped PM');
    });
  });

  group('LogDeduplicationService.deduplicateByDay', () {
    test('folds three same-day logs with the same field rules', () {
      final day = DateTime(2026, 9, 7);
      final logs = [
        _log(
          id: 'a',
          date: day.add(const Duration(hours: 8)),
          createdAt: day.add(const Duration(hours: 8)),
          itch: 4,
          lesion: 'mild',
          mood: 3,
          areas: const ['face'],
          notes: 'am',
        ),
        _log(
          id: 'b',
          date: day.add(const Duration(hours: 12)),
          createdAt: day.add(const Duration(hours: 12)),
          itch: 9,
          lesion: 'none',
          mood: 2,
          areas: const ['hands'],
          notes: 'noon',
        ),
        _log(
          id: 'c',
          date: day.add(const Duration(hours: 21)),
          createdAt: day.add(const Duration(hours: 21)),
          itch: 1,
          lesion: 'moderate',
          mood: 5,
          areas: const ['face'],
          notes: 'pm',
        ),
      ];

      final result = LogDeduplicationService.deduplicateByDay(logs);
      expect(result, hasLength(1));
      final merged = result.single;
      expect(merged.itchIntensity, 9);
      expect(merged.lesionSeverity, 'moderate');
      expect(merged.mood, 5);
      expect(merged.affectedAreas, ['face', 'hands']);
      expect(merged.notes, 'pm');
      expect(merged.id, 'a');
    });
  });

  group('DailyLogService.addLog same-day aggregation', () {
    late DailyLogService service;

    setUp(() {
      service = DailyLogService();
      service.clearAllLogs();
    });

    tearDown(() {
      service.clearAllLogs();
    });

    test('second check-in merges instead of whole-record replace', () {
      final morning = DateTime(2026, 9, 7, 8);
      final evening = DateTime(2026, 9, 7, 20);

      service.addLog(
        _log(
          id: 'am',
          date: morning,
          createdAt: morning,
          itch: 9,
          mood: 5,
          lesion: 'mild',
          areas: const ['scalp'],
          notes: 'itchy morning',
        ),
        quiet: true,
      );
      service.addLog(
        _log(
          id: 'pm',
          date: evening,
          createdAt: evening,
          itch: 2,
          mood: 2,
          lesion: 'severe',
          areas: const ['elbows'],
          notes: 'worse plaques',
        ),
        quiet: true,
      );

      final logs = service.getLogs();
      expect(logs, hasLength(1));
      final merged = logs.single;
      expect(merged.itchIntensity, 9);
      expect(merged.lesionSeverity, 'severe');
      expect(merged.mood, 2);
      expect(merged.affectedAreas, ['scalp', 'elbows']);
      expect(merged.notes, 'worse plaques');
      expect(merged.id, 'am');
      expect(service.getRawLogs(), hasLength(1));
    });
  });
}
