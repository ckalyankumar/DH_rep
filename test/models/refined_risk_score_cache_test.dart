import 'package:flutter_test/flutter_test.dart';
import 'package:dhealth/data/disorder_registry.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/log_analytics.dart';
import 'package:dhealth/models/refined_risk_score_cache.dart';
import 'package:dhealth/models/risk_score_result.dart';

DailyLog _log({
  required String id,
  required DateTime date,
  int itch = 5,
  int mood = 3,
  int stress = 4,
  String condition = 'psoriasis',
}) {
  return DailyLog(
    id: id,
    date: date,
    condition: condition,
    mood: mood,
    itchIntensity: itch,
    stressLevel: stress,
    lesionSeverity: 'mild',
    affectedAreas: const ['arm'],
    sleepQuality: 3,
    sleepDisruption: false,
    notes: '',
  );
}

RiskScoreResult _stub(int score) {
  return RiskScoreResult(
    finalScore: score,
    band: 'low',
    components: const {},
    trendModifier: 0,
    triggerModifier: 0,
    redFlagOverride: false,
    explanation: const [],
  );
}

void main() {
  final now = DateTime(2026, 9, 7, 12);

  group('RefinedRiskScoreCache', () {
    test('first call computes; identical inputs reuse the cached result', () {
      final cache = RefinedRiskScoreCache();
      final logs = [_log(id: 'a', date: now)];

      final first = cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(42),
      );
      final second = cache.getOrCompute(
        logs: List<DailyLog>.from(logs),
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(99),
      );

      expect(first.finalScore, 42);
      expect(second.finalScore, 42);
      expect(identical(first, second), isTrue);
      expect(cache.computeCount, 1);
    });

    test('adding a log invalidates and recomputes', () {
      final cache = RefinedRiskScoreCache();
      final firstLogs = [_log(id: 'a', date: now.subtract(const Duration(days: 1)))];
      cache.getOrCompute(
        logs: firstLogs,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(10),
      );

      final withToday = [
        ...firstLogs,
        _log(id: 'b', date: now, itch: 9),
      ];
      final updated = cache.getOrCompute(
        logs: withToday,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(70),
      );

      expect(updated.finalScore, 70);
      expect(cache.computeCount, 2);
    });

    test('replacing a log (new id, same day) invalidates', () {
      final cache = RefinedRiskScoreCache();
      cache.getOrCompute(
        logs: [_log(id: 'old', date: now, itch: 2)],
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(20),
      );

      final replaced = cache.getOrCompute(
        logs: [_log(id: 'new', date: now, itch: 9)],
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(80),
      );

      expect(replaced.finalScore, 80);
      expect(cache.computeCount, 2);
    });

    test('switching selectedCondition invalidates', () {
      final cache = RefinedRiskScoreCache();
      final logs = [_log(id: 'a', date: now)];
      cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(30),
      );

      final eczema = cache.getOrCompute(
        logs: logs,
        condition: 'eczema',
        envData: null,
        now: now,
        compute: () => _stub(35),
      );

      expect(eczema.finalScore, 35);
      expect(cache.computeCount, 2);
    });

    test('env data arriving (null → new map) invalidates', () {
      final cache = RefinedRiskScoreCache();
      final logs = [_log(id: 'a', date: now)];
      cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(11),
      );

      final env = {
        'weather': {
          'main': {'temp': 4, 'humidity': 20},
        },
      };
      final withEnv = cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: env,
        now: now,
        compute: () => _stub(22),
      );

      expect(withEnv.finalScore, 22);
      expect(cache.computeCount, 2);

      // Same map reference: treat as unchanged (unrelated setState).
      cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: env,
        now: now,
        compute: () => _stub(99),
      );
      expect(cache.computeCount, 2);
    });

    test('new env map instance invalidates even if previous result exists', () {
      final cache = RefinedRiskScoreCache();
      final logs = [_log(id: 'a', date: now)];
      cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: {
          'weather': {
            'main': {'temp': 20, 'humidity': 50},
          },
        },
        now: now,
        compute: () => _stub(1),
      );

      cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: {
          'weather': {
            'main': {'temp': 3, 'humidity': 20},
          },
        },
        now: now,
        compute: () => _stub(2),
      );

      expect(cache.computeCount, 2);
    });

    test('calendar-day rollover invalidates (90-day window / today log)', () {
      final cache = RefinedRiskScoreCache();
      final logs = [_log(id: 'a', date: now)];
      cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => _stub(5),
      );

      cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: null,
        now: now.add(const Duration(days: 1)),
        compute: () => _stub(6),
      );

      expect(cache.computeCount, 2);
    });
  });

  group('LogAnalytics.getRefinedRiskScore at 90-day volume', () {
    test('adding a 90th log changes the refined score vs a cached prior result',
        () {
      final cache = RefinedRiskScoreCache();
      final disorder = DisorderRegistry.getDisorder('psoriasis');
      final logs = <DailyLog>[
        for (var i = 0; i < 89; i++)
          _log(
            id: 'd$i',
            date: now.subtract(Duration(days: 89 - i)),
            itch: 3 + (i % 4),
          ),
      ];

      final withoutToday = cache.getOrCompute(
        logs: logs,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => LogAnalytics(logs).getRefinedRiskScore(
          'psoriasis',
          disorder,
        ),
      );

      final withToday = [...logs, _log(id: 'today', date: now, itch: 10)];
      final updated = cache.getOrCompute(
        logs: withToday,
        condition: 'psoriasis',
        envData: null,
        now: now,
        compute: () => LogAnalytics(withToday).getRefinedRiskScore(
          'psoriasis',
          disorder,
        ),
      );

      expect(cache.computeCount, 2);
      expect(updated.finalScore, isNot(withoutToday.finalScore));
    });

    test('90-log compute stays cheap enough that isolates are not required',
        () {
      final disorder = DisorderRegistry.getDisorder('psoriasis');
      final logs = <DailyLog>[
        for (var i = 0; i < 90; i++)
          _log(
            id: 'd$i',
            date: now.subtract(Duration(days: 89 - i)),
            itch: 2 + (i % 6),
            stress: 2 + (i % 5),
          ),
      ];

      final sw = Stopwatch()..start();
      LogAnalytics(logs).getRefinedRiskScore('psoriasis', disorder);
      sw.stop();

      // Desktop VM; if this ever approaches hundreds of ms on-device we can
      // revisit compute()/isolates. Memoization is the right first fix.
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });
}
