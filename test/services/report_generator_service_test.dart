import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/medication_profile.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/weekly_focus.dart';
import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/services/report_generator_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  DailyLog makeLog({
    required DateTime date,
    int mood = 3,
    int itch = 5,
    int stress = 5,
    bool sleepDisruption = false,
  }) {
    return DailyLog(
      id: 'log-${date.toIso8601String()}',
      condition: 'psoriasis',
      mood: mood,
      itchIntensity: itch,
      stressLevel: stress,
      lesionSeverity: 'none',
      affectedAreas: const [],
      sleepQuality: 3,
      sleepDisruption: sleepDisruption,
      notes: '',
      date: date,
    );
  }

  test('generateHealthReport minimal call produces a document', () async {
    final logs = <DailyLog>[];
    final now = DateTime.now();

    final doc = await ReportGeneratorService.generateHealthReport(
      patientName: 'Patient',
      condition: 'psoriasis',
      logs: logs,
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now,
    );

    final bytes = await doc.save();
    expect(bytes.length, greaterThan(0));
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
        focusText: 'Apply moisturiser twice daily',
        recommendationId: null,
        triggerCategory: null,
        outcome: WeeklyFocusOutcome.accepted,
        createdAt: DateTime.now(),
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

    final doc = await ReportGeneratorService.generateHealthReport(
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
      aggregates: aggregates,
      wearableSources: wearableSources,
      patientDateOfBirth: DateTime(1990, 1, 15),
      patientAbhaId: '12-3456-7890-1234',
    );

    final bytes = await doc.save();
    expect(bytes.length, greaterThan(0));
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

    final doc = await ReportGeneratorService.generateHealthReport(
      patientName: 'Patient',
      condition: 'psoriasis',
      logs: logs,
      startDate: start,
      endDate: start.add(const Duration(days: 9)),
    );

    final bytes = await doc.save();
    expect(bytes.length, greaterThan(0));
  });
}

