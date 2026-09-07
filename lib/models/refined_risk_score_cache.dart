import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/risk_score_result.dart';

/// Memoizes [RiskScoreResult] so [LogAnalytics.getRefinedRiskScore] is not
/// re-run on every widget rebuild.
///
/// Invalidation is input-driven, not setState-driven: a new log id, condition
/// change, a new envData map instance, or calendar-day rollover produces a new
/// key. Unrelated rebuilds (tab switches, snackbars, loading flags) reuse the
/// cache.
class RefinedRiskScoreCache {
  RefinedRiskScoreCacheKey? _key;
  RiskScoreResult? _result;

  /// How many times [compute] has actually run. Used by tests as a spy.
  int computeCount = 0;

  RiskScoreResult getOrCompute({
    required List<DailyLog> logs,
    required String condition,
    Map<String, dynamic>? envData,
    required RiskScoreResult Function() compute,
    DateTime? now,
  }) {
    final key = RefinedRiskScoreCacheKey.fromInputs(
      logs: logs,
      condition: condition,
      envData: envData,
      now: now,
    );
    final cached = _result;
    if (cached != null && _key == key) {
      return cached;
    }
    computeCount++;
    final result = compute();
    _key = key;
    _result = result;
    return result;
  }
}

/// Inputs that affect [LogAnalytics.getRefinedRiskScore].
///
/// [DailyLog] fields are `final`, so a log add/replace/remove always changes
/// the id set. [envData] is compared by identity so assigning a new map (env
/// data arriving or a refresh) invalidates, while an unchanged reference does
/// not.
class RefinedRiskScoreCacheKey {
  const RefinedRiskScoreCacheKey({
    required this.sortedLogIds,
    required this.condition,
    required this.envData,
    required this.year,
    required this.month,
    required this.day,
  });

  final List<String> sortedLogIds;
  final String condition;
  final Map<String, dynamic>? envData;
  final int year;
  final int month;
  final int day;

  factory RefinedRiskScoreCacheKey.fromInputs({
    required List<DailyLog> logs,
    required String condition,
    Map<String, dynamic>? envData,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final ids = logs.map((l) => l.id).toList()..sort();
    return RefinedRiskScoreCacheKey(
      sortedLogIds: ids,
      condition: condition,
      envData: envData,
      year: n.year,
      month: n.month,
      day: n.day,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RefinedRiskScoreCacheKey &&
        other.condition == condition &&
        other.year == year &&
        other.month == month &&
        other.day == day &&
        identical(other.envData, envData) &&
        _listEquals(other.sortedLogIds, sortedLogIds);
  }

  @override
  int get hashCode => Object.hash(
        condition,
        year,
        month,
        day,
        identityHashCode(envData),
        Object.hashAll(sortedLogIds),
      );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
