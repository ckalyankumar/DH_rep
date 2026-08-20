import 'package:flutter/material.dart';

import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';
import 'package:dhealth/services/firestore_weekly_pulse_service.dart';

/// Single-question pulse: "How confident do you feel in managing your
/// skin condition this week?" (0–10).
///
/// Frictionless: slider or tap scale. First-time shows one-line explanation.
class WeeklyPulseDialog extends StatefulWidget {
  final FirestoreWeeklyPulseService pulseService;
  final String condition;
  final bool showFirstTimeExplanation;
  final VoidCallback? onSaved;

  const WeeklyPulseDialog({
    super.key,
    required this.pulseService,
    required this.condition,
    this.showFirstTimeExplanation = false,
    this.onSaved,
  });

  /// Show if due (auto-prompt) or when forceShow is true (manual from menu)
  static Future<void> showIfDue(
    BuildContext context, {
    required FirestoreWeeklyPulseService pulseService,
    required String condition,
    required bool hasPulseThisWeek,
    required bool hasEverSubmittedPulse,
    bool forceShow = false,
    VoidCallback? onSaved,
  }) async {
    if (!forceShow && hasPulseThisWeek) return;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WeeklyPulseDialog(
        pulseService: pulseService,
        condition: condition,
        showFirstTimeExplanation: !hasEverSubmittedPulse,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<WeeklyPulseDialog> createState() => _WeeklyPulseDialogState();
}

class _WeeklyPulseDialogState extends State<WeeklyPulseDialog> {
  int _score = 5;
  bool _isSaving = false;

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final weekStart = WeeklySelfEfficacyPulse.getWeekStart(DateTime.now());
      final pulse = WeeklySelfEfficacyPulse(
        id: WeeklySelfEfficacyPulse.weekIdFromDate(weekStart),
        weekStartDate: weekStart,
        score: _score,
        condition: widget.condition,
        createdAt: DateTime.now(),
      );
      await widget.pulseService.savePulse(pulse);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved?.call();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weekly check-in'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showFirstTimeExplanation) ...[
              Text(
                'This helps us understand how you\'re feeling about your condition, '
                'separate from symptoms.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'How confident do you feel in managing your skin condition this week?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score / 10',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Slider(
              value: _score.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$_score',
              onChanged: (v) => setState(() => _score = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Not at all', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text('Very confident', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
