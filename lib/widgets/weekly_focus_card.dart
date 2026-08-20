import 'package:flutter/material.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/weekly_focus.dart';
import 'package:dhealth/services/weekly_focus_service.dart';
import 'package:dhealth/services/weekly_focus_suggestion_engine.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/widgets/skeleton_widgets.dart';
import 'package:dhealth/utils/theme.dart';

class WeeklyFocusCard extends StatefulWidget {
  final String uid;
  final String condition;
  final List<DailyLog> recentLogs; // last 30 days
  final List<ProAssessment> proAssessments;

  const WeeklyFocusCard({
    super.key,
    required this.uid,
    required this.condition,
    required this.recentLogs,
    required this.proAssessments,
  });

  @override
  State<WeeklyFocusCard> createState() => _WeeklyFocusCardState();
}

class _WeeklyFocusCardState extends State<WeeklyFocusCard> {
  final WeeklyFocusService _service = WeeklyFocusService();
  final WeeklyFocusSuggestionEngine _engine = WeeklyFocusSuggestionEngine();

  bool _loading = true;
  WeeklyFocus? _currentFocus;
  List<WeeklyFocusSuggestion> _suggestions = [];
  bool _showPatientEntry = false;
  bool _dismissedForSession = false;
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    setState(() {
      _loading = true;
    });

    try {
      final focus = await _service.getFocusForCurrentWeek(
        widget.uid,
        widget.condition,
      );

      if (!mounted) return;

      if (focus != null && focus.outcome != WeeklyFocusOutcome.declined) {
        setState(() {
          _currentFocus = focus;
          _loading = false;
        });
        return;
      }

      final suggestions = _engine.generateSuggestions(
        recentLogs: widget.recentLogs,
        condition: widget.condition,
        proAssessments: widget.proAssessments,
      );

      setState(() {
        _currentFocus = null;
        _suggestions = suggestions;
        _showPatientEntry = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _acceptSuggestion(WeeklyFocusSuggestion suggestion) async {
    final focus = WeeklyFocus(
      id: suggestion.recommendationId,
      uid: widget.uid,
      weekStartDate: WeeklyFocus.currentWeekStart(),
      condition: widget.condition,
      source: WeeklyFocusSource.appGenerated,
      focusText: suggestion.text,
      recommendationId: suggestion.recommendationId,
      triggerCategory: suggestion.triggerCategory == 'general'
          ? null
          : suggestion.triggerCategory,
      outcome: WeeklyFocusOutcome.accepted,
      createdAt: DateTime.now().toUtc(),
    );

    setState(() {
      _loading = true;
    });

    try {
      await _service.saveFocus(focus);
      if (!mounted) return;
      setState(() {
        _currentFocus = focus;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _setPatientEnteredFocus() async {
    final text = _customController.text.trim();
    if (text.isEmpty) return;

    final focus = WeeklyFocus(
      id: 'patient_${WeeklyFocus.currentWeekStart().toIso8601String()}',
      uid: widget.uid,
      weekStartDate: WeeklyFocus.currentWeekStart(),
      condition: widget.condition,
      source: WeeklyFocusSource.patientEntered,
      focusText: text,
      recommendationId: null,
      triggerCategory: null,
      outcome: WeeklyFocusOutcome.patientEntered,
      createdAt: DateTime.now().toUtc(),
    );

    setState(() {
      _loading = true;
    });

    try {
      await _service.saveFocus(focus);
      if (!mounted) return;
      setState(() {
        _currentFocus = focus;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedForSession) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const SkeletonLogCard();
    }

    if (_currentFocus != null && _currentFocus!.outcome != WeeklyFocusOutcome.declined) {
      return _buildCurrentFocusCard(context, _currentFocus!);
    }

    if (_showPatientEntry) {
      return _buildPatientEntryCard(context);
    }

    return _buildSuggestionsCard(context);
  }

  Widget _buildCurrentFocusCard(BuildContext context, WeeklyFocus focus) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THIS WEEK\'S FOCUS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.warningColor,
                letterSpacing: 0.08,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              focus.focusText,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (focus.triggerCategory != null)
              Text(
                'Linked to your ${focus.triggerCategory} pattern.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Focus',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose one small thing to focus on this week.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ..._suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _acceptSuggestion(s),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.text,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          s.rationale,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showPatientEntry = true;
                  });
                },
                child: const Text('Set my own focus'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showPatientEntry = true;
                  });
                },
                child: const Text('None of these fit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientEntryCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your focus for this week',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _customController,
              maxLength: 120,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'What would you like to focus on this week?',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _setPatientEnteredFocus,
                  child: const Text('Set focus'),
                ),
                const SizedBox(width: AppSpacing.md),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dismissedForSession = true;
                    });
                  },
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

