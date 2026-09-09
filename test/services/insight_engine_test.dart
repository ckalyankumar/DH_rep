import 'package:flutter_test/flutter_test.dart';
import 'package:dhealth/data/disorder_registry.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/personal_weight_calculator.dart';
import 'package:dhealth/services/risk_score_calculator.dart';
import 'package:dhealth/config/risk_score_config.dart';

DailyLog _log({
  required int dayOffset,
  DateTime? today,
  int itch = 3,
  int stress = 3,
  int mood = 4,
  int sleepQuality = 4,
  bool sleepDisruption = false,
  List<String>? triggers,
  List<String>? structuredTriggerIds,
  String condition = 'psoriasis',
}) {
  final base = today ?? DateTime(2026, 9, 9);
  final date = DateTime(base.year, base.month, base.day)
      .subtract(Duration(days: dayOffset));
  return DailyLog(
    id: 'log-$dayOffset',
    condition: condition,
    mood: mood,
    itchIntensity: itch,
    stressLevel: stress,
    lesionSeverity: 'mild',
    affectedAreas: const ['arm'],
    sleepQuality: sleepQuality,
    sleepDisruption: sleepDisruption,
    notes: '',
    date: date,
    triggers: triggers,
    structuredTriggerIds: structuredTriggerIds,
  );
}

/// Newest-first, matching LogDeduplicationService.deduplicateByDay.
List<DailyLog> _descending(List<DailyLog> logs) {
  return List<DailyLog>.from(logs)..sort((a, b) => b.date.compareTo(a.date));
}

List<DailyLog> _ascending(List<DailyLog> logs) {
  return List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
}

void main() {
  final disorder = DisorderRegistry.getDisorder('psoriasis');
  final eczema = DisorderRegistry.getDisorder('eczema');

  group('Fix 1: detectRedFlags uses the most recent log, not the oldest', () {
    test(
        'fires on today even when the list is newest-first and the oldest day is calm',
        () {
      // dayOffset 0 = today (emergency), 1..6 = calm older days.
      final logs = _descending([
        _log(dayOffset: 0, itch: 9, mood: 1, sleepDisruption: true),
        for (var i = 1; i <= 6; i++) _log(dayOffset: i, itch: 2, mood: 4),
      ]);

      expect(logs.last.itchIntensity, 2,
          reason: 'newest-first: .last is the oldest');
      expect(logs.first.itchIntensity, 9);

      final flags = InsightEngine.detectRedFlags(logs, disorder);
      expect(flags, isNotEmpty);
      expect(flags.any((f) => f.urgency == 'emergency'), isTrue);
    });

    test('does not fire when only the oldest day meets emergency criteria', () {
      final logs = _descending([
        _log(dayOffset: 0, itch: 2, mood: 4),
        for (var i = 1; i <= 5; i++) _log(dayOffset: i, itch: 3, mood: 4),
        _log(dayOffset: 6, itch: 9, mood: 1, sleepDisruption: true),
      ]);

      final flags = InsightEngine.detectRedFlags(logs, disorder);
      expect(flags, isEmpty);
    });

    test('ascending and descending input produce the same flags', () {
      final raw = [
        _log(dayOffset: 0, itch: 9, mood: 1, sleepDisruption: true),
        _log(dayOffset: 1, itch: 2),
        _log(dayOffset: 2, itch: 3),
      ];
      final a = InsightEngine.detectRedFlags(_ascending(raw), disorder);
      final b = InsightEngine.detectRedFlags(_descending(raw), disorder);
      expect(
          a.map((f) => f.symptom).toList(), b.map((f) => f.symptom).toList());
    });
  });

  group('Fix 2: detectPatterns Improving/Worsening is not inverted', () {
    test(
        'labels Improving when recent half is better, even on a newest-first list',
        () {
      final logs = _descending([
        for (var i = 0; i < 7; i++) _log(dayOffset: i, itch: 2),
        for (var i = 7; i < 14; i++) _log(dayOffset: i, itch: 8),
      ]);

      final patterns = InsightEngine.detectPatterns(logs);
      final trend = patterns.where((p) => p.pattern.contains('Trend'));
      expect(trend, isNotEmpty);
      expect(trend.first.pattern, contains('Improving'));
      expect(trend.first.pattern, isNot(contains('Worsening')));
    });

    test(
        'labels Worsening when recent half is worse, even on a newest-first list',
        () {
      final logs = _descending([
        for (var i = 0; i < 7; i++) _log(dayOffset: i, itch: 8),
        for (var i = 7; i < 14; i++) _log(dayOffset: i, itch: 2),
      ]);

      final patterns = InsightEngine.detectPatterns(logs);
      final trend = patterns.where((p) => p.pattern.contains('Trend'));
      expect(trend, isNotEmpty);
      expect(trend.first.pattern, contains('Worsening'));
    });
  });

  group('Fix 3: predictFlareRisk uses recent 7 days and today, not the oldest',
      () {
    test(
        'recent-window itch is taken from the newest 7 days on a newest-first list',
        () {
      final logs = _descending([
        for (var i = 0; i < 7; i++)
          _log(dayOffset: i, itch: 1, stress: 2, sleepQuality: 5, mood: 5),
        for (var i = 7; i < 14; i++)
          _log(dayOffset: i, itch: 9, stress: 2, sleepQuality: 5, mood: 5),
      ]);

      final pred = InsightEngine.predictFlareRisk(logs, const []);
      // Newest-7 avg itch = 1 → base 10%. Oldest-7 would have been 90%.
      expect(pred.riskPercentage, closeTo(10.0, 0.01));
    });

    test('stress/sleep/mood adjustments use today, not the oldest log', () {
      final logs = _descending([
        _log(
          dayOffset: 0,
          itch: 5,
          stress: 8,
          sleepQuality: 1,
          sleepDisruption: true,
          mood: 1,
        ),
        for (var i = 1; i < 7; i++)
          _log(
            dayOffset: i,
            itch: 5,
            stress: 1,
            sleepQuality: 5,
            sleepDisruption: false,
            mood: 5,
          ),
      ]);

      final pred = InsightEngine.predictFlareRisk(logs, const []);
      // base 50 + stress 15 + sleepQuality 15 + disruption 10 + mood 10 = 100
      expect(pred.riskPercentage, 100.0);
    });
  });

  group('Fix 4: generateDailyInsights health score uses today', () {
    test(
        'headline score follows today, not the oldest log, on a newest-first list',
        () async {
      final logs = _descending([
        _log(
          dayOffset: 0,
          itch: 1,
          mood: 5,
          sleepQuality: 5,
          sleepDisruption: false,
        ),
        _log(
          dayOffset: 1,
          itch: 10,
          mood: 1,
          sleepQuality: 1,
          sleepDisruption: true,
        ),
      ]);

      final summary = await InsightEngine.generateDailyInsights(
        logs,
        'psoriasis',
        disorder,
      );

      // today: 100 - 5 - 0 - 0 = 95; oldest would clamp to 0
      expect(summary.healthScore, 95);
    });
  });

  group('Fix 5: RiskScoreCalculator passes sorted logs into detectRedFlags',
      () {
    test(
        'red-flag override fires when only today is an emergency, newest-first input',
        () {
      final logs = _descending([
        _log(dayOffset: 0, itch: 9, mood: 1, sleepDisruption: true),
        for (var i = 1; i <= 6; i++) _log(dayOffset: i, itch: 2, mood: 4),
      ]);

      final result = RiskScoreCalculator.calculate(
        logs: logs,
        condition: 'psoriasis',
        disorder: disorder,
      );

      expect(result.redFlagOverride, isTrue);
      expect(result.band, redFlagOverrideBand);
      expect(result.finalScore, greaterThanOrEqualTo(redFlagOverrideMinScore));
    });

    test(
        'red-flag override does not fire when only the oldest day is an emergency',
        () {
      final logs = _descending([
        _log(dayOffset: 0, itch: 2, mood: 4),
        for (var i = 1; i <= 5; i++) _log(dayOffset: i, itch: 3, mood: 4),
        _log(dayOffset: 6, itch: 9, mood: 1, sleepDisruption: true),
      ]);

      final result = RiskScoreCalculator.calculate(
        logs: logs,
        condition: 'psoriasis',
        disorder: disorder,
      );

      expect(result.redFlagOverride, isFalse);
    });
  });

  group('Fix 6: lag correlation multiple-comparisons correction', () {
    test(
        'calculateLagCorrelation omits lags with fewer than 10 remaining points',
        () {
      final cause = List<num>.generate(16, (i) => i.toDouble());
      final effect = List<num>.generate(16, (i) => i.toDouble());
      final lags =
          InsightEngine.calculateLagCorrelation(cause, effect, maxLag: 7);

      // n=16, remaining = 16-lag; eligible iff remaining >= 10 → lag <= 6
      expect(lags.containsKey(7), isFalse);
      expect(lags.containsKey(6), isTrue);
      expect(lags.keys.toList()..sort(), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('n=10 only computes lag 0 (lag 1 would leave 9 points)', () {
      final cause = List<num>.generate(10, (i) => i.toDouble());
      final effect = List<num>.generate(10, (i) => i.toDouble());
      final lags =
          InsightEngine.calculateLagCorrelation(cause, effect, maxLag: 7);
      expect(lags.keys, [0]);
    });

    test('Bonferroni critical |r| via Fisher z matches the documented formula',
        () {
      // r_crit = tanh(1.960 / sqrt(10-3)) ≈ 0.632 at n=10, K=1
      expect(
        InsightEngine.bonferroniCriticalAbsR(n: 10, lagCount: 1),
        closeTo(0.632, 0.005),
      );
      // K=8, n=30: tanh(2.734 / sqrt(27)) ≈ 0.482
      expect(
        InsightEngine.bonferroniCriticalAbsR(n: 30, lagCount: 8),
        closeTo(0.482, 0.005),
      );
    });

    test(
        'bestSignificantLag rejects |r| above the 0.55 floor but below Bonferroni',
        () {
      final crit = InsightEngine.bonferroniCriticalAbsR(n: 10, lagCount: 1);
      expect(crit, greaterThan(0.55));

      final rejected = InsightEngine.bestSignificantLag(
        {0: 0.58},
        seriesLength: 10,
        minAbsR: 0.55,
      );
      expect(rejected, isNull);

      final accepted = InsightEngine.bestSignificantLag(
        {0: 0.95},
        seriesLength: 10,
        minAbsR: 0.55,
      );
      expect(accepted, isNotNull);
      expect(accepted!.lag, 0);
    });

    test('a 3-point lag-7 spike is not eligible as the best lag', () {
      // 10 points: lag 7 would have used 3 pairs under the old min-n=3 rule.
      // Construct a series whose last-3 / first-3 relationship is perfect but
      // the eligible lag-0 correlation is weak.
      final cause = <num>[1, 2, 3, 4, 5, 6, 7, 9, 1, 2];
      final effect = <num>[2, 1, 3, 2, 4, 3, 5, 1, 2, 9];
      final lags =
          InsightEngine.calculateLagCorrelation(cause, effect, maxLag: 7);
      expect(lags.containsKey(7), isFalse);

      final best = InsightEngine.bestSignificantLag(
        lags,
        seriesLength: cause.length,
        minAbsR: 0.55,
      );
      expect(best?.lag, isNot(7));
    });
  });

  group('Fix 7: trigger mapping does not silently fall back to stress', () {
    test(
        'every psoriasis and eczema registry trigger is mapped or skipped, never defaulted',
        () {
      final sample = [_log(dayOffset: 0, stress: 9)];
      final names = [
        ...disorder.triggers.map((t) => t.name),
        ...eczema.triggers.map((t) => t.name),
      ];

      const mapped = {
        'Psychological Stress',
        'Alcohol Consumption',
        'Smoking',
        'Stress & Sleep Deprivation',
      };
      const skipped = {
        'Cold Weather & Low Humidity',
        'Cold Weather & Temperature Drops',
        'Food Allergen Exposure (Milk, Nuts, Eggs)',
        'Environmental Allergens (Dust Mites, Pollen, Pet Dander)',
        'Bacterial Infection (Streptococcal)',
        'Skin Trauma (Koebner Phenomenon)',
        'Obesity (BMI >30)',
        'Medications (Beta-blockers, NSAIDs, Lithium)',
        'High Humidity + Sweating',
        'Harsh Soaps, Detergents, Fragrances',
        'Dry Air & Low Humidity (less than 30%)',
        'Bacterial Infection (Staph aureus Colonization)',
        'Itch-Scratch Cycle / Lichenification',
      };

      expect(mapped.union(skipped), names.toSet(),
          reason: 'registry changed — update mapping + this test');

      for (final name in names) {
        final series = InsightEngine.metricSeriesForTrigger(name, sample);
        if (mapped.contains(name)) {
          expect(series, isNotNull,
              reason: '$name should map to a real signal');
        } else {
          expect(series, isNull,
              reason: '$name should be skipped, not aliased');
        }
      }
    });

    test(
        'stress–itch correlation does not label Smoking/Alcohol/Obesity/Trauma/Meds',
        () {
      // Perfect stress–itch relationship, no lifestyle tags.
      final logs = [
        for (var i = 0; i < 20; i++)
          _log(
            dayOffset: i,
            itch: i.isEven ? 8 : 2,
            stress: i.isEven ? 9 : 1,
          ),
      ];

      final detected = InsightEngine.identifyTriggers(
        _descending(logs),
        'psoriasis',
        disorder,
      );
      final names = detected.map((t) => t.name).toSet();

      expect(names, contains('Psychological Stress'));
      expect(names, isNot(contains('Smoking')));
      expect(names, isNot(contains('Alcohol Consumption')));
      expect(names, isNot(contains('Obesity (BMI >30)')));
      expect(names, isNot(contains('Skin Trauma (Koebner Phenomenon)')));
      expect(names,
          isNot(contains('Medications (Beta-blockers, NSAIDs, Lithium)')));
      expect(names, isNot(contains('Cold Weather & Low Humidity')));
    });

    test('Alcohol is detected from diet.alcohol tags, not from stress', () {
      final logs = [
        for (var i = 0; i < 20; i++)
          _log(
            dayOffset: i,
            itch: i.isEven ? 8 : 2,
            stress: 5, // constant — no stress signal
            structuredTriggerIds: i.isEven ? ['diet.alcohol'] : null,
          ),
      ];

      final detected = InsightEngine.identifyTriggers(
        _descending(logs),
        'psoriasis',
        disorder,
      );
      final names = detected.map((t) => t.name).toSet();
      expect(names, contains('Alcohol Consumption'));
      expect(names, isNot(contains('Psychological Stress')));
      expect(names, isNot(contains('Smoking')));
      expect(
        detected
            .firstWhere((t) => t.name == 'Alcohol Consumption')
            .coverageNote,
        isNull,
      );
    });

    test('Smoking is detected from tagged trigger text, not from stress', () {
      final logs = [
        for (var i = 0; i < 20; i++)
          _log(
            dayOffset: i,
            itch: i.isEven ? 8 : 2,
            stress: 5,
            triggers: i.isEven ? ['smoking'] : null,
          ),
      ];

      final detected = InsightEngine.identifyTriggers(
        _descending(logs),
        'psoriasis',
        disorder,
      );
      expect(detected.map((t) => t.name), contains('Smoking'));
    });

    test(
        'eczema itch-scratch / dry air / soaps are skipped even when stress tracks itch',
        () {
      final logs = [
        for (var i = 0; i < 20; i++)
          _log(
            dayOffset: i,
            condition: 'eczema',
            itch: i.isEven ? 8 : 2,
            stress: i.isEven ? 9 : 1,
            sleepQuality: i.isEven ? 1 : 5,
          ),
      ];

      final detected = InsightEngine.identifyTriggers(
        _descending(logs),
        'eczema',
        eczema,
      );
      final names = detected.map((t) => t.name).toSet();
      expect(names, contains('Stress & Sleep Deprivation'));
      expect(names, isNot(contains('Itch-Scratch Cycle / Lichenification')));
      expect(names, isNot(contains('Dry Air & Low Humidity (less than 30%)')));
      expect(names, isNot(contains('Harsh Soaps, Detergents, Fragrances')));
      expect(names, isNot(contains('High Humidity + Sweating')));
      expect(
          names, isNot(contains('Food Allergen Exposure (Milk, Nuts, Eggs)')));
      expect(
        names,
        isNot(contains(
          'Environmental Allergens (Dust Mites, Pollen, Pet Dander)',
        )),
      );
      expect(names, isNot(contains('Cold Weather & Temperature Drops')));
    });

    test('dairy tags do not produce a Food Allergen detected trigger', () {
      final logs = [
        for (var i = 0; i < 20; i++)
          _log(
            dayOffset: i,
            condition: 'eczema',
            itch: i.isEven ? 8 : 2,
            stress: 5,
            structuredTriggerIds: i.isEven ? ['diet.dairy'] : null,
          ),
      ];
      final detected = InsightEngine.identifyTriggers(
        _descending(logs),
        'eczema',
        eczema,
      );
      expect(
        detected.map((t) => t.name),
        isNot(contains('Food Allergen Exposure (Milk, Nuts, Eggs)')),
      );
    });
  });

  group('coverageNote infrastructure', () {
    test('current mapped triggers leave coverageNote null', () {
      final sample = [_log(dayOffset: 0)];
      for (final name in [
        'Psychological Stress',
        'Alcohol Consumption',
        'Smoking',
        'Stress & Sleep Deprivation',
      ]) {
        expect(
          InsightEngine.metricMappingForTrigger(name, sample)?.coverageNote,
          isNull,
          reason:
              '$name is full coverage; caveat reserved for future partial maps',
        );
      }
    });
  });

  group('PersonalWeightCalculator lag selection uses Bonferroni', () {
    test('returns a profile from 30 days without using sub-min-n lags', () {
      final logs = [
        for (var i = 0; i < 30; i++)
          _log(
            dayOffset: i,
            itch: 3 + (i % 4),
            stress: 2 + (i % 5),
            sleepQuality: 2 + (i % 3),
            mood: 2 + (i % 3),
          ),
      ];
      final profile = PersonalWeightCalculator.computePersonalWeightProfile(
        _descending(logs),
        psoriasisRiskWeights,
      );
      expect(profile, isNotNull);
      expect(profile!.dataDaysUsed, 30);
    });
  });
}
