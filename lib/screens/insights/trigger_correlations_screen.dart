import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/services/firestore_daily_log_service.dart';
import 'package:dhealth/widgets/trigger_insight_card.dart';
import 'package:dhealth/utils/theme.dart';

/// Screen showing all trigger–PRO correlations in a ListView.
class TriggerCorrelationsScreen extends StatefulWidget {
  final List<DailyLog> logs;
  final List<ProAssessment> pros;
  final String condition;

  const TriggerCorrelationsScreen({
    super.key,
    required this.logs,
    required this.pros,
    required this.condition,
  });

  /// Build from current user data (fetches from Firestore).
  static Future<TriggerCorrelationsScreen?> fromCurrentUser(
    BuildContext context,
    String condition,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final logService = FirestoreDailyLogService(userId: user.uid);
    final logs = await logService.getLogsForLastDays(365);

    final proSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('proAssessments')
        .get();
    final pros = proSnap.docs
        .map((d) => ProAssessment.fromJson(d.data(), id: d.id))
        .toList();

    return TriggerCorrelationsScreen(
      logs: logs,
      pros: pros,
      condition: condition,
    );
  }

  @override
  State<TriggerCorrelationsScreen> createState() =>
      _TriggerCorrelationsScreenState();
}

class _TriggerCorrelationsScreenState extends State<TriggerCorrelationsScreen> {
  late List<TriggerProCorrelation> _correlations;

  @override
  void initState() {
    super.initState();
    _correlations = TriggerProCorrelationEngine.correlate(
      widget.logs,
      widget.pros,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trigger insights'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _correlations.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Not enough data yet. Log daily and complete weekly questionnaires for at least 8 weeks to see trigger insights.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _correlations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return TriggerInsightCard(
                  correlation: _correlations[index],
                  condition: widget.condition,
                );
              },
            ),
    );
  }
}
