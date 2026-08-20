import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/flare_candidate.dart';
import 'package:dhealth/models/flare_event.dart';
import 'package:dhealth/services/firestore_flare_candidate_service.dart';
import 'package:dhealth/services/firestore_flare_event_service.dart';

class FlareDetectionService {
  static const int itchThreshold = 7;

  final FirestoreFlareCandidateService _candidateService;
  final FirestoreFlareEventService _eventService;

  FlareDetectionService({
    FirestoreFlareCandidateService? candidateService,
    FirestoreFlareEventService? eventService,
  })  : _candidateService = candidateService ?? FirestoreFlareCandidateService(),
        _eventService = eventService ?? FirestoreFlareEventService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Stage 1: detect/update a candidate window from recent logs.
  ///
  /// Returns the candidate if detected (even if previously stored), otherwise null.
  Future<FlareCandidate?> detectCandidateFromRecentLogs(
    List<DailyLog> logs, {
    int lookbackDays = 14,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final recent = _dedupeByDay(logs)
        .where((l) => DateTime.now().difference(l.date).inDays <= lookbackDays)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (recent.length < 3) return null;

    // Check the most recent rolling 3-day window that qualifies.
    for (int i = recent.length - 1; i >= 2; i--) {
      final a = recent[i - 2];
      final b = recent[i - 1];
      final c = recent[i];

      if (!_areConsecutiveDays(a.date, b.date) || !_areConsecutiveDays(b.date, c.date)) {
        continue;
      }

      final itchHits =
          (a.itchIntensity >= itchThreshold ? 1 : 0) +
          (b.itchIntensity >= itchThreshold ? 1 : 0) +
          (c.itchIntensity >= itchThreshold ? 1 : 0);

      if (itchHits < 2) continue;

      final hasFunctionalImpact = a.sleepDisruption ||
          b.sleepDisruption ||
          c.sleepDisruption ||
          a.mood <= 2 ||
          b.mood <= 2 ||
          c.mood <= 2 ||
          a.lesionSeverity == 'severe' ||
          b.lesionSeverity == 'severe' ||
          c.lesionSeverity == 'severe';

      if (!hasFunctionalImpact) continue;

      final windowStart = _dayStart(a.date);
      final windowEnd = _dayStart(c.date);
      final id = FirestoreFlareCandidateService.candidateIdForWindowStart(windowStart);

      final candidate = FlareCandidate(
        id: id,
        uid: uid,
        windowStartDate: windowStart,
        windowEndDate: windowEnd,
        metricsSnapshot: {
          'itch': {
            _dayKey(a.date): a.itchIntensity,
            _dayKey(b.date): b.itchIntensity,
            _dayKey(c.date): c.itchIntensity,
          },
          'sleepDisruption': {
            _dayKey(a.date): a.sleepDisruption,
            _dayKey(b.date): b.sleepDisruption,
            _dayKey(c.date): c.sleepDisruption,
          },
          'mood': {
            _dayKey(a.date): a.mood,
            _dayKey(b.date): b.mood,
            _dayKey(c.date): c.mood,
          },
          'lesionSeverity': {
            _dayKey(a.date): a.lesionSeverity,
            _dayKey(b.date): b.lesionSeverity,
            _dayKey(c.date): c.lesionSeverity,
          },
        },
        detectedAt: DateTime.now(),
      );

      await _candidateService.upsertCandidate(candidate);
      await _promoteStaleUnansweredCandidateToUnconfirmed(candidate);
      await _updateResolutionForOpenEvents(recent);
      return candidate;
    }

    // Still attempt resolution updates when no new candidate is detected.
    await _updateResolutionForOpenEvents(recent);
    return null;
  }

  Future<void> markCandidatePrompted(FlareCandidate candidate) async {
    final uid = _uid;
    if (uid == null) return;
    await _candidateService.upsertCandidate(
      candidate.copyWith(promptedAt: DateTime.now()),
    );
  }

  Future<void> respondToCandidate(
    FlareCandidate candidate, {
    required FlareCandidateResponse response,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now();
    final isDismiss = response == FlareCandidateResponse.notReally;
    final updated = candidate.copyWith(
      response: response,
      respondedAt: now,
      patientDismissed: isDismiss,
    );
    await _candidateService.upsertCandidate(updated);

    if (response == FlareCandidateResponse.yes) {
      final id = FirestoreFlareEventService.eventIdForOnset(
        candidate.windowStartDate,
        FlareEventSource.confirmedHybrid,
      );
      await _eventService.upsertEvent(
        FlareEvent(
          id: id,
          uid: uid,
          onsetDate: candidate.windowStartDate,
          source: FlareEventSource.confirmedHybrid,
          metricsSnapshot: candidate.metricsSnapshot,
          candidateId: candidate.id,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> logPatientInitiatedFlare({
    required DateTime onsetDate,
    Map<String, dynamic>? metricsSnapshot,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now();
    final id = FirestoreFlareEventService.eventIdForOnset(
      onsetDate,
      FlareEventSource.patientInitiated,
    );
    await _eventService.upsertEvent(
      FlareEvent(
        id: id,
        uid: uid,
        onsetDate: onsetDate,
        source: FlareEventSource.patientInitiated,
        metricsSnapshot: metricsSnapshot,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _promoteStaleUnansweredCandidateToUnconfirmed(
    FlareCandidate candidate,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    final stored = await _candidateService.getById(candidate.id);
    if (stored == null) return;
    if (stored.response != null || stored.patientDismissed) return;
    if (stored.promptedAt == null) return;

    final hours = DateTime.now().difference(stored.promptedAt!).inHours;
    if (hours < 48) return;

    final now = DateTime.now();
    final id = FirestoreFlareEventService.eventIdForOnset(
      stored.windowStartDate,
      FlareEventSource.algorithmUnconfirmed,
    );
    await _eventService.upsertEvent(
      FlareEvent(
        id: id,
        uid: uid,
        onsetDate: stored.windowStartDate,
        source: FlareEventSource.algorithmUnconfirmed,
        metricsSnapshot: stored.metricsSnapshot,
        candidateId: stored.id,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _updateResolutionForOpenEvents(List<DailyLog> recentLogs) async {
    final uid = _uid;
    if (uid == null) return;

    // Best-effort: only consider events with onset in last 180 days.
    final events = await _eventService.getForLastDays(days: 180);
    final open = events.where((e) => e.resolutionDate == null).toList();
    if (open.isEmpty) return;

    final byDay = <String, DailyLog>{};
    for (final l in _dedupeByDay(recentLogs)) {
      byDay[_dayKey(l.date)] = l;
    }

    for (final event in open) {
      final onset = _dayStart(event.onsetDate);
      final orderedDays = byDay.keys.toList()..sort();

      // Find the first pair of consecutive days AFTER onset where itch < threshold.
      DateTime? firstBelow;
      for (final k in orderedDays) {
        final d = DateTime.parse(k);
        if (!d.isAfter(onset)) continue;
        final log = byDay[k];
        if (log == null) continue;
        if (log.itchIntensity < itchThreshold) {
          firstBelow ??= d;
          final next = d.add(const Duration(days: 1));
          final nextKey = _dayKey(next);
          final nextLog = byDay[nextKey];
          if (nextLog != null && nextLog.itchIntensity < itchThreshold) {
            await _eventService.upsertEvent(
              event.copyWith(
                resolutionDate: d,
                updatedAt: DateTime.now(),
              ),
            );
            break;
          }
        } else {
          firstBelow = null;
        }
      }
    }
  }

  static List<DailyLog> _dedupeByDay(List<DailyLog> logs) {
    final byDay = <String, DailyLog>{};
    for (final log in logs) {
      final key = _dayKey(log.date);
      final existing = byDay[key];
      if (existing == null || log.calculateRiskScore() > existing.calculateRiskScore()) {
        byDay[key] = log;
      }
    }
    return byDay.values.toList();
  }

  static bool _areConsecutiveDays(DateTime a, DateTime b) {
    final da = _dayStart(a);
    final db = _dayStart(b);
    return db.difference(da).inDays == 1;
  }

  static DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _dayKey(DateTime dt) {
    final d = _dayStart(dt);
    return d.toIso8601String().substring(0, 10);
  }
}

