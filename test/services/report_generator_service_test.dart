import 'dart:async';
import 'dart:typed_data';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/flare_event.dart';
import 'package:dhealth/models/medication_exception_event.dart';
import 'package:dhealth/models/medication_profile.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/weekly_focus.dart';
import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/services/report_generator_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

bool _isFontWarning(String line) {
  return line.contains('Unable to find a font') ||
      line.contains('no Unicode support') ||
      line.contains('too many exceptions');
}

class _SavedReport {
  final Uint8List bytes;
  final int pageCount;
  _SavedReport(this.bytes, this.pageCount);
}

Future<_SavedReport> _generateWithoutFontWarnings(
  Future<pw.Document> Function() build,
) async {
  final warnings = <String>[];
  late Uint8List bytes;
  late int pageCount;
  await Zone.current.fork(
    specification: ZoneSpecification(
      print: (self, parent, zone, line) {
        warnings.add(line);
        parent.print(zone, line);
      },
    ),
  ).run(() async {
    final doc = await build();
    bytes = await doc.save();
    pageCount = doc.document.pdfPageList.pages.length;
  });
  final fontIssues = warnings.where(_isFontWarning).toList();
  expect(
    fontIssues,
    isEmpty,
    reason: 'PDF font warnings:\n${fontIssues.join('\n')}',
  );
  return _SavedReport(bytes, pageCount);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DailyLog makeLog({
    required DateTime date,
    int mood = 3,
    int itch = 5,
    int stress = 5,
    bool sleepDisruption = false,
    String notes = '',
    List<String> affectedAreas = const [],
  }) {
    return DailyLog(
      id: 'log-${date.toIso8601String()}',
      condition: 'psoriasis',
      mood: mood,
      itchIntensity: itch,
      stressLevel: stress,
      lesionSeverity: 'none',
      affectedAreas: affectedAreas,
      sleepQuality: 3,
      sleepDisruption: sleepDisruption,
      notes: notes,
      date: date,
    );
  }

  test('generateHealthReport minimal call produces a document', () async {
    final logs = <DailyLog>[];
    final now = DateTime.now();

    final report = await _generateWithoutFontWarnings(
      () => ReportGeneratorService.generateHealthReport(
        patientName: 'Patient',
        condition: 'psoriasis',
        logs: logs,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now,
      ),
    );
    expect(report.bytes.length, greaterThan(0));
    expect(report.pageCount, inInclusiveRange(1, 4));
  });

  test('bundled PDF fonts cover em dash, ellipsis, bullet, rho, and dingbats',
      () async {
    final fonts = [
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      await rootBundle.load('assets/fonts/NotoSansMath-Regular.ttf'),
      await rootBundle.load('assets/fonts/NotoSansSymbols2-Regular.ttf'),
    ];
    final cmaps = fonts.map((d) => TtfParser(d).charToGlyphIndexMap).toList();
    const required = {
      0x2013: 'en dash',
      0x2014: 'em dash',
      0x2022: 'bullet',
      0x2026: 'ellipsis',
      0x03C1: 'rho',
      0x2264: 'less-than or equal',
      0x2265: 'greater-than or equal',
      0x2713: 'check mark',
      0x2717: 'ballot x',
    };
    required.forEach((rune, name) {
      expect(
        cmaps.any((cmap) => (cmap[rune] ?? 0) != 0),
        isTrue,
        reason: 'fonts missing $name (U+${rune.toRadixString(16)})',
      );
    });
  });

  test('generateHealthReport full call produces a document', () async {
    final start = DateTime.now().subtract(const Duration(days: 30));
    final logs = List.generate(
      5,
      (i) => makeLog(date: start.add(Duration(days: i))),
    );

    final medicationProfile = MedicationProfile(
      uid: 'user-1',
      treatmentType: MedicationTreatmentType.topical,
      medicationName: 'Calcipotriol',
      startDate: start,
      updatedAt: DateTime.now(),
    );

    final weeklyPulses = [
      WeeklySelfEfficacyPulse(
        id: 'p1',
        weekStartDate: WeeklySelfEfficacyPulse.getWeekStart(start),
        score: 7,
        condition: 'psoriasis',
        createdAt: start,
      ),
    ];

    final proAssessments = [
      ProAssessment(
        id: 'a1',
        type: ProAssessmentType.poem,
        condition: 'eczema',
        date: start,
        totalScore: 10,
        severityBand: 'moderate eczema',
        responses: const [],
      ),
      ProAssessment(
        id: 'a2',
        type: ProAssessmentType.dlqi,
        condition: 'psoriasis',
        date: start.add(const Duration(days: 7)),
        totalScore: 8,
        severityBand: 'moderate',
        responses: const [],
      ),
    ];

    final triggerProCorrelations = [
      TriggerProCorrelation(
        category: 'stress',
        r: 0.6,
        weeks: 10,
        avgProHigh: 12.0,
        avgProLow: 6.0,
      ),
    ];

    final weeklyFocuses = [
      WeeklyFocus(
        id: 'f1',
        uid: 'user-1',
        weekStartDate: WeeklyFocus.currentWeekStart(),
        condition: 'psoriasis',
        source: WeeklyFocusSource.patientEntered,
        focusText:
            'Apply moisturiser twice daily and avoid wool clothing during flares — keep notes…',
        recommendationId: null,
        triggerCategory: null,
        outcome: WeeklyFocusOutcome.accepted,
        createdAt: DateTime.now(),
      ),
    ];

    final now = DateTime.now();
    final medicationExceptions = [
      MedicationExceptionEvent(
        id: 'ex1',
        uid: 'user-1',
        type: MedicationExceptionType.missedDose,
        occurredAt: start.add(const Duration(days: 1)),
        logDate: start.add(const Duration(days: 1)),
        note: 'Forgot evening dose',
        createdAt: now,
      ),
      MedicationExceptionEvent(
        id: 'ex2',
        uid: 'user-1',
        type: MedicationExceptionType.sideEffect,
        occurredAt: start.add(const Duration(days: 2)),
        logDate: start.add(const Duration(days: 2)),
        createdAt: now,
      ),
    ];

    final flareEvents = [
      FlareEvent(
        id: 'fl1',
        uid: 'user-1',
        onsetDate: start.add(const Duration(days: 2)),
        resolutionDate: start.add(const Duration(days: 4)),
        source: FlareEventSource.patientInitiated,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final aggregates = [
      DailyWearableAggregate(
        uid: 'user-1',
        date: DateFormat('yyyy-MM-dd').format(start),
        provider: WearableProvider.fitbit,
        totalSleepMinutes: 420,
        deepSleepPercent: null,
        remSleepPercent: null,
        awakenings: null,
        sleepScore: null,
        hrvNightly: 55.0,
        hrvReadiness: null,
        restingHeartRate: null,
        steps: 8000,
        activeMinutes: null,
        deviceStressScore: null,
        syncedAt: DateTime.now(),
      ),
    ];

    final wearableSources = [
      WearableSource(
        id: 'src1',
        uid: 'user-1',
        provider: WearableProvider.fitbit,
        scopes: const [],
        encryptedOauthToken: 'token',
        lastSyncedAt: DateTime.now(),
        isActive: true,
        consentGrantedAt: start,
      ),
    ];

    final report = await _generateWithoutFontWarnings(
      () => ReportGeneratorService.generateHealthReport(
        patientName: 'Patient',
        condition: 'psoriasis',
        logs: logs,
        startDate: start,
        endDate: start.add(const Duration(days: 4)),
        medicationProfile: medicationProfile,
        weeklyPulses: weeklyPulses,
        proAssessments: proAssessments,
        triggerProCorrelations: triggerProCorrelations,
        weeklyFocuses: weeklyFocuses,
        medicationExceptions: medicationExceptions,
        flareEvents: flareEvents,
        aggregates: aggregates,
        wearableSources: wearableSources,
        patientDateOfBirth: DateTime(1990, 1, 15),
        patientAbhaId: '12-3456-7890-1234',
      ),
    );
    expect(report.bytes.length, greaterThan(0));
    expect(report.pageCount, inInclusiveRange(1, 8));
  });

  test('generateHealthReport with 30 daily logs paginates without TooManyPages',
      () async {
    final start = DateTime(2026, 7, 1);
    final logs = List.generate(
      30,
      (i) => makeLog(
        date: start.add(Duration(days: i)),
        itch: 4 + (i % 5),
        notes: 'Day $i notes with enough text to wrap a line or two',
        affectedAreas: const ['elbows', 'knees', 'scalp'],
      ),
    );

    final report = await _generateWithoutFontWarnings(
      () => ReportGeneratorService.generateHealthReport(
        patientName: 'Test Patient With A Long Name',
        condition: 'psoriasis',
        logs: logs,
        startDate: start,
        endDate: start.add(const Duration(days: 29)),
      ),
    );
    expect(report.bytes.length, greaterThan(0));
    expect(report.pageCount, inInclusiveRange(2, 8));
  });

  test('generateHealthReport with 365 daily logs stays a reasonable length',
      () async {
    final start = DateTime(2025, 8, 1);
    final logs = List.generate(
      365,
      (i) => makeLog(
        date: start.add(Duration(days: i)),
        itch: 3 + (i % 6),
        notes: i % 7 == 0 ? 'Weekly review note for day $i' : '',
        affectedAreas: i % 3 == 0 ? const ['elbows', 'knees'] : const [],
      ),
    );

    final report = await _generateWithoutFontWarnings(
      () => ReportGeneratorService.generateHealthReport(
        patientName: 'Year-Long Patient',
        condition: 'psoriasis',
        logs: logs,
        startDate: start,
        endDate: start.add(const Duration(days: 364)),
      ),
    );
    expect(report.bytes.length, greaterThan(0));
    // Compact spanning table: a count near maxPages (40) would mean layout
    // is still runaway, just under the limit.
    expect(report.pageCount, inInclusiveRange(6, 16));
  });

  test('generateHealthReport edge-case full payload saves with bounded pages',
      () async {
    final start = DateTime(2026, 1, 1);
    final now = DateTime(2026, 3, 1);
    final logs = List.generate(
      60,
      (i) => makeLog(
        date: start.add(Duration(days: i)),
        itch: i % 10 == 0 ? 9 : 4,
        mood: i % 10 == 0 ? 1 : 3,
        sleepDisruption: i % 10 == 0,
        notes: 'Longitudinal note $i — em dash — ρ check',
        affectedAreas: const ['scalp', 'elbows', 'lower back'],
      ),
    );

    final weeklyPulses = List.generate(
      12,
      (i) => WeeklySelfEfficacyPulse(
        id: 'p$i',
        weekStartDate: start.add(Duration(days: i * 7)),
        score: 4 + (i % 5),
        condition: 'psoriasis',
        createdAt: start.add(Duration(days: i * 7)),
      ),
    );

    final proAssessments = List.generate(8, (i) {
      final isPoem = i.isEven;
      return ProAssessment(
        id: 'a$i',
        type: isPoem ? ProAssessmentType.poem : ProAssessmentType.dlqi,
        condition: isPoem ? 'eczema' : 'psoriasis',
        date: start.add(Duration(days: i * 7)),
        totalScore: isPoem ? 8 + i : 6 + i,
        severityBand: isPoem ? 'moderate eczema' : 'moderate',
        responses: const [],
      );
    });

    final triggerProCorrelations = [
      for (final cat in ['stress', 'sleep', 'diet', 'environment'])
        TriggerProCorrelation(
          category: cat,
          r: 0.45,
          weeks: 12,
          avgProHigh: 14.0,
          avgProLow: 7.0,
        ),
    ];

    final weeklyFocuses = List.generate(
      8,
      (i) => WeeklyFocus(
        id: 'f$i',
        uid: 'user-1',
        weekStartDate: start.add(Duration(days: i * 7)),
        condition: 'psoriasis',
        source: WeeklyFocusSource.patientEntered,
        focusText:
            'Apply moisturiser twice daily and avoid wool clothing during flares — keep detailed notes of itch peaks',
        recommendationId: null,
        triggerCategory: 'stress',
        outcome: WeeklyFocusOutcome.accepted,
        createdAt: now,
      ),
    );

    final medicationExceptions = List.generate(
      10,
      (i) => MedicationExceptionEvent(
        id: 'ex$i',
        uid: 'user-1',
        type: i.isEven
            ? MedicationExceptionType.missedDose
            : MedicationExceptionType.sideEffect,
        occurredAt: start.add(Duration(days: i + 1)),
        logDate: start.add(Duration(days: i + 1)),
        note: i.isEven ? null : 'Burning at application site on day $i',
        createdAt: now,
      ),
    );

    final flareEvents = List.generate(
      6,
      (i) => FlareEvent(
        id: 'fl$i',
        uid: 'user-1',
        onsetDate: start.add(Duration(days: 5 + i * 8)),
        resolutionDate: start.add(Duration(days: 8 + i * 8)),
        source: FlareEventSource.patientInitiated,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final aggregates = List.generate(
      30,
      (i) => DailyWearableAggregate(
        uid: 'user-1',
        date: DateFormat('yyyy-MM-dd').format(start.add(Duration(days: i))),
        provider: WearableProvider.fitbit,
        totalSleepMinutes: 360 + (i % 90),
        hrvNightly: 35.0 + (i % 20),
        steps: 4000 + i * 50,
        syncedAt: now,
      ),
    );

    final wearableCorrelations = [
      for (final metric in [
        'wearable.hrv',
        'wearable.sleep',
        'wearable.steps',
        'wearable.stress',
        'wearable.readiness',
        'wearable.restingHr',
      ])
        TriggerProCorrelation(
          category: metric,
          r: -0.4,
          weeks: 10,
          avgProHigh: 11.0,
          avgProLow: 7.5,
        ),
    ];

    final report = await _generateWithoutFontWarnings(
      () => ReportGeneratorService.generateHealthReport(
        patientName: 'Alexandra Catherine Montgomery-Singh',
        condition: 'psoriasis',
        logs: logs,
        startDate: start,
        endDate: start.add(const Duration(days: 59)),
        medicationProfile: MedicationProfile(
          uid: 'user-1',
          treatmentType: MedicationTreatmentType.combinationTherapy,
          medicationName: 'Calcipotriol + betamethasone dipropionate',
          startDate: start,
          updatedAt: now,
        ),
        weeklyPulses: weeklyPulses,
        proAssessments: proAssessments,
        triggerProCorrelations: triggerProCorrelations,
        weeklyFocuses: weeklyFocuses,
        medicationExceptions: medicationExceptions,
        flareEvents: flareEvents,
        aggregates: aggregates,
        wearableCorrelations: wearableCorrelations,
        wearableSources: [
          WearableSource(
            id: 'src1',
            uid: 'user-1',
            provider: WearableProvider.fitbit,
            scopes: const [
              WearableScope.sleep,
              WearableScope.hrv,
              WearableScope.activity,
            ],
            encryptedOauthToken: 'token',
            lastSyncedAt: now,
            isActive: true,
            consentGrantedAt: start,
          ),
        ],
        patientDateOfBirth: DateTime(1984, 11, 2),
        patientAbhaId: '12-3456-7890-1234',
      ),
    );
    expect(report.bytes.length, greaterThan(0));
    expect(report.pageCount, inInclusiveRange(3, 16));
  });

  test('generateHealthReport with red flag logs completes', () async {
    final start = DateTime.now().subtract(const Duration(days: 10));
    final logs = <DailyLog>[
      makeLog(
        date: start,
        itch: 9,
        sleepDisruption: true,
        mood: 1,
      ),
      makeLog(
        date: start.add(const Duration(days: 1)),
        itch: 9,
        sleepDisruption: true,
        mood: 1,
      ),
      makeLog(
        date: start.add(const Duration(days: 2)),
        itch: 3,
      ),
    ];

    final report = await _generateWithoutFontWarnings(
      () => ReportGeneratorService.generateHealthReport(
        patientName: 'Patient',
        condition: 'psoriasis',
        logs: logs,
        startDate: start,
        endDate: start.add(const Duration(days: 9)),
      ),
    );
    expect(report.bytes.length, greaterThan(0));
    expect(report.pageCount, inInclusiveRange(1, 6));
  });
}
