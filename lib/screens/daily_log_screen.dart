import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/widgets/mood_selector_widget.dart';
import 'package:dhealth/widgets/custom_slider_widget.dart';
import 'package:dhealth/widgets/wearable_prefill_badges.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/services/firestore_daily_log_service.dart';
import 'package:dhealth/services/firestore_medication_exception_service.dart';
import 'package:dhealth/services/wearable_checkin_prefill_service.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/config/trigger_taxonomy.dart';
import 'package:dhealth/models/medication_exception_event.dart';

class DailyLogScreen extends StatefulWidget {
  final DailyLogService dailyLogService;
  final FirestoreDailyLogService? firestoreService; // nullable for web
  final String condition;

  const DailyLogScreen({
    super.key,
    required this.dailyLogService,
    required this.condition,
    this.firestoreService,
  });

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  int selectedMood = 3;
  int itchIntensity = 5;
  int stressLevel = 6;
  String lesionSeverity = 'none';
  Set<String> affectedAreas = {};
  int sleepQuality = 3;
  bool sleepDisruption = false;
  String notes = '';
  int currentStreak = 7;

  bool showAutoSaveMessage = false;
  String autoSaveStatus = 'Changes saved';
  bool isSaving = false;

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _treatmentNoteController = TextEditingController();

  DailyWearableAggregate? _aggregate;
  WearableCheckinPrefill? _prefill;
  bool _showBanner = true;

  bool _sleepQualityOverridden = false;
  bool _sleepDisruptionOverridden = false;
  bool _stressOverridden = false;
  late final List<TriggerCategory> _triggerCategories;
  final Set<String> _selectedTriggerIds = {};
  String _otherTriggerText = '';
  bool _triggersExpanded = false;
  bool _hasHighTriggerPriorUsage = false;

  String? _treatmentNoteAction;

  @override
  void initState() {
    super.initState();
    _triggerCategories = defaultTriggerTaxonomy(widget.condition);
    _notesController.addListener(_onAnyFieldChange);
    _treatmentNoteController.addListener(_onAnyFieldChange);
    _loadTodayLog();
    _computeTriggerPriorUsage();
    _loadPrefill();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _waitForAuthThenSave();
    });
  }

  Future<void> _loadPrefill() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _aggregate = await WearableRepository().getAggregate(uid, today);
      _prefill = WearableCheckinPrefillService().prefill(_aggregate);
      if (_prefill != null && mounted) {
        if (_prefill!.hasSleepQuality) {
          sleepQuality = _prefill!.sleepQuality!;
        }
        if (_prefill!.hasSleepDisruption) {
          sleepDisruption = _prefill!.sleepDisruption!;
        }
        if (_prefill!.hasStress) {
          stressLevel = _prefill!.stress!;
        }
        setState(() {});
      }
    } catch (_) {
      _prefill = null;
    }
  }

  @override
  void dispose() {
    _notesController.removeListener(_onAnyFieldChange);
    _notesController.dispose();
    _treatmentNoteController.removeListener(_onAnyFieldChange);
    _treatmentNoteController.dispose();
    super.dispose();
  }

  void _loadTodayLog() {
    final todayLog = widget.dailyLogService.getTodayLog();
    if (todayLog != null) {
      setState(() {
        selectedMood = todayLog.mood;
        itchIntensity = todayLog.itchIntensity;
        stressLevel = todayLog.stressLevel;
        lesionSeverity = todayLog.lesionSeverity;
        affectedAreas = Set<String>.from(todayLog.affectedAreas);
        sleepQuality = todayLog.sleepQuality;
        sleepDisruption = todayLog.sleepDisruption;
        notes = todayLog.notes;
        _notesController.text = todayLog.notes;
        _treatmentNoteAction = todayLog.treatmentNoteAction;
        _treatmentNoteController.text = todayLog.treatmentNoteText ?? '';
      });
    }
  }

  Future<void> _recordMedicationExceptionIfNeeded({
    required String action,
    required DateTime logDate,
    required String note,
  }) async {
    final type = switch (action) {
      'missedDose' => MedicationExceptionType.missedDose,
      'sideEffect' => MedicationExceptionType.sideEffect,
      'changedDose' => MedicationExceptionType.changedDose,
      'stopped' => MedicationExceptionType.stopped,
      _ => null,
    };

    if (type == null) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirestoreMedicationExceptionService().addException(
        type: type,
        logDate: logDate,
        note: note.trim().isEmpty ? null : note.trim(),
        condition: widget.condition,
      );
    } catch (e) {
      // Non-blocking: daily log can still save locally/cloud.
      debugPrint('Medication exception save failed: $e');
    }
  }

  void _setTreatmentNoteAction(String? next) {
    setState(() {
      if (_treatmentNoteAction == next) {
        _treatmentNoteAction = null;
        _treatmentNoteController.text = '';
      } else {
        _treatmentNoteAction = next;
        if (next == 'allGood' || next == 'missedDose') {
          _treatmentNoteController.text = '';
        }
      }
    });
    _onAnyFieldChange();

    final selected = _treatmentNoteAction;
    if (selected == null) return;

    if (selected == 'missedDose' ||
        selected == 'sideEffect' ||
        selected == 'changedDose' ||
        selected == 'stopped') {
      _recordMedicationExceptionIfNeeded(
        action: selected,
        logDate: DateTime.now(),
        note: _treatmentNoteController.text,
      );
    }
  }

  String _buildTriggerSummaryLabel() {
    if (_selectedTriggerIds.isEmpty) {
      if (_hasHighTriggerPriorUsage) {
        return 'Any triggers today? (Tap to add)';
      }
      return 'No triggers selected — tap to add';
    }

    final count = _selectedTriggerIds.length;
    final suffix = count == 1 ? '' : 's';
    return '$count trigger$suffix selected';
  }

  void _computeTriggerPriorUsage() {
    final lastSevenLogs =
        widget.dailyLogService.getLogsFromLastDays(7);
    int withTriggers = 0;
    for (final log in lastSevenLogs) {
      final hasAnyTriggers =
          (log.triggers != null && log.triggers!.isNotEmpty) ||
              (log.structuredTriggerIds != null &&
                  log.structuredTriggerIds!.isNotEmpty);
      if (hasAnyTriggers) {
        withTriggers++;
      }
    }
    _hasHighTriggerPriorUsage = withTriggers >= 3;
  }

  void _onAnyFieldChange() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      _autoSave();
    });
  }

  Future<void> _autoSave() async {
    if (isSaving) return;

    setState(() {
      isSaving = true;
      autoSaveStatus = 'Saving...';
      showAutoSaveMessage = true;
    });

    try {
      final existingLog = widget.dailyLogService.getTodayLog();
      if (existingLog != null) {
        widget.dailyLogService.removeLogById(existingLog.id);
      }

      final triggerLabels = <String>[];
      for (final cat in _triggerCategories) {
        for (final opt in cat.options) {
          final id = opt.id.full;
          if (_selectedTriggerIds.contains(id)) {
            triggerLabels.add(opt.displayLabel);
          }
        }
      }
      if (_otherTriggerText.trim().isNotEmpty) {
        triggerLabels.add(_otherTriggerText.trim());
      }

      final structuredIds = _selectedTriggerIds.toList();

      widget.dailyLogService.createAndAdd(
        condition: widget.condition,
        mood: selectedMood,
        itchIntensity: itchIntensity,
        stressLevel: stressLevel,
        lesionSeverity: lesionSeverity,
        affectedAreas: affectedAreas.toList(),
        sleepQuality: sleepQuality,
        sleepDisruption: sleepDisruption,
        notes: _notesController.text.trim(),
        date: DateTime.now(),
        triggers: triggerLabels.isEmpty ? null : triggerLabels,
        structuredTriggerIds:
            structuredIds.isEmpty ? null : structuredIds,
        treatmentNoteAction: _treatmentNoteAction,
        treatmentNoteText: _treatmentNoteController.text.trim().isEmpty
            ? null
            : _treatmentNoteController.text.trim(),
        wearableRawSleepMinutes: _prefill?.rawSleepMinutes,
        wearableRawAwakenings: _prefill?.rawAwakenings,
        wearableRawDeviceStress: _prefill?.rawDeviceStress,
        wearableProvider: _prefill?.provider,
        wearablePrefillSyncedAt: _prefill?.syncedAt,
        sleepQualityWasOverridden: _sleepQualityOverridden,
        sleepDisruptionWasOverridden: _sleepDisruptionOverridden,
        stressWasOverridden: _stressOverridden,
      );

      // Save to Firestore only if available (mobile)
      final newLog = widget.dailyLogService.getTodayLog();
      final successMsg = _prefill != null && _prefill!.prefillCount > 0
          ? 'Check-in saved · ${_prefill!.prefillCount} field(s) from ${_capitalizeProvider(_prefill!.provider)}'
          : null;
      await _saveLogToCloudSafe(newLog, successMessage: successMsg);
      // cloud sync attempted

      setState(() {
        autoSaveStatus = 'Saved';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => showAutoSaveMessage = false);
        }
      });
    } catch (e) {
      setState(() {
        autoSaveStatus = 'Error: $e';
      });
      debugPrint('Auto-save error: $e');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _waitForAuthThenSave() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      await current.reload();
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final log = widget.dailyLogService.getTodayLog();
      if (log != null) {
        await _saveLogToCloudSafe(log);
      }
    }
  }

  Future<void> _saveLogToCloudSafe(DailyLog? newLog,
      {String? successMessage, bool showSuccessSnackBar = false}) async {
    if (newLog == null || widget.firestoreService == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to sync your log to the cloud.'),
        ),
      );
      return;
    }

    try {
      await widget.firestoreService!.saveLog(newLog);
      if (!mounted) return;
      if (showSuccessSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage ?? 'Cloud log saved successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('DailyLogScreen _saveLogToCloudSafe ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save log to cloud: $e'),
        ),
      );
    }
  }

  void _handleMoodChange(int mood) {
    setState(() => selectedMood = mood);
    _onAnyFieldChange();
  }

  void _handleItchChange(int value) {
    setState(() => itchIntensity = value);
    _onAnyFieldChange();
  }

  void _handleStressChange(int value) {
    setState(() {
      stressLevel = value;
      if (_prefill?.hasStress == true) _stressOverridden = true;
    });
    _onAnyFieldChange();
  }

  void _handleAreaToggle(String area) {
    setState(() {
      if (affectedAreas.contains(area)) {
        affectedAreas.remove(area);
      } else {
        affectedAreas.add(area);
      }
    });
    _onAnyFieldChange();
  }

  void _handleLesionChange(String value) {
    setState(() => lesionSeverity = value);
    _onAnyFieldChange();
  }

  void _handleSleepQualityChange(int value) {
    setState(() {
      sleepQuality = value;
      if (_prefill?.hasSleepQuality == true) _sleepQualityOverridden = true;
    });
    _onAnyFieldChange();
  }

  void _handleSleepDisruptionChange(bool? value) {
    setState(() {
      sleepDisruption = value ?? false;
      if (_prefill?.hasSleepDisruption == true) _sleepDisruptionOverridden = true;
    });
    _onAnyFieldChange();
  }

  void _toggleTriggerSelection(String id) {
    setState(() {
      if (_selectedTriggerIds.contains(id)) {
        _selectedTriggerIds.remove(id);
      } else {
        _selectedTriggerIds.add(id);
      }
    });
    _onAnyFieldChange();
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}, ${now.year}';
  }

  Widget _buildFormSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2c3e50),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  static String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _capitalizeProvider(String provider) {
    if (provider.isEmpty) return provider;
    return '${provider[0].toUpperCase()}${provider.substring(1)}';
  }

  Widget _buildWearableSummaryBanner() {
    final prefill = _prefill!;
    final providerName = _capitalizeProvider(prefill.provider);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          gradient: const LinearGradient(
            colors: [AppTheme.primaryDark, AppTheme.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '⌚ $providerName · synced ${_timeAgo(prefill.syncedAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha:0.65),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha:0.6),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showBanner = false),
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Good morning — here's last night",
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_aggregate?.totalSleepMinutes != null) ...[
                      _buildMetricPill(
                        'Sleep',
                        '${_aggregate!.totalSleepMinutes! ~/ 60}h ${(_aggregate!.totalSleepMinutes! % 60).round()}m',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (prefill.rawAwakenings != null) ...[
                      _buildMetricPill('Awakenings', '${prefill.rawAwakenings}'),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (_aggregate?.restingHeartRate != null) ...[
                      _buildMetricPill('Resting HR', '${_aggregate!.restingHeartRate} bpm'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'We pre-filled ${prefill.prefillCount} field(s) below — adjust if needed.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha:0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha:0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSleepQualityBadge() {
    if (_prefill == null || !_prefill!.hasSleepQuality) return null;
    return _sleepQualityOverridden
        ? const ManualBadge()
        : WearableBadge(provider: _prefill!.provider);
  }

  Widget? _buildSleepDisruptionBadge() {
    if (_prefill == null || !_prefill!.hasSleepDisruption) return null;
    return _sleepDisruptionOverridden
        ? const ManualBadge()
        : WearableBadge(provider: _prefill!.provider);
  }

  Widget? _buildStressBadge() {
    if (_prefill == null || !_prefill!.hasStress) return null;
    return _stressOverridden
        ? const ManualBadge()
        : WearableBadge(provider: _prefill!.provider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Symptom Log'),
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & Streak
                Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCurrentDate(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Current Streak: '),
                        Text(
                          '$currentStreak days',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_prefill != null &&
                _prefill!.prefillCount > 0 &&
                _showBanner)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _buildWearableSummaryBanner(),
              ),

            // Test login for Firestore (web / debug)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signInAnonymously();
                    await _waitForAuthThenSave();
                  } catch (e) {
                    debugPrint('Anonymous login from DailyLogScreen failed: $e');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Login failed: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Login Anonymously (for Firestore)'),
              ),
            ),
            const SizedBox(height: 16),

            // Mood
            _buildFormSection(
              title: 'How\'s your mood?',
              child: MoodSelectorWidget(
                initialMood: selectedMood,
                onMoodChanged: _handleMoodChange,
              ),
            ),
            const SizedBox(height: 24),

            // Itch Intensity
            _buildFormSection(
              title: 'Itch Intensity',
              child: CustomSliderWidget(
                label: 'Itch Intensity (0-10)',
                initialValue: itchIntensity,
                min: 0,
                max: 10,
                onChanged: _handleItchChange,
              ),
            ),
            const SizedBox(height: 24),

            // Stress Level
            _buildFormSection(
              title: 'Stress Level',
              trailing: _buildStressBadge(),
              child: _prefill != null &&
                      _prefill!.hasStress &&
                      !_stressOverridden
                  ? Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.wearableBlue.withValues(alpha:0.5),
                          width: 1.5,
                        ),
                        color: AppTheme.wearableBlue.withValues(alpha:0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomSliderWidget(
                        key: ValueKey('stress_$stressLevel'),
                        label: 'Stress Level (0-10)',
                        initialValue: stressLevel,
                        min: 0,
                        max: 10,
                        onChanged: _handleStressChange,
                        activeTrackColor: AppTheme.wearableBlue,
                      ),
                    )
                  : CustomSliderWidget(
                      key: ValueKey('stress_$stressLevel'),
                      label: 'Stress Level (0-10)',
                      initialValue: stressLevel,
                      min: 0,
                      max: 10,
                      onChanged: _handleStressChange,
                    ),
            ),
            const SizedBox(height: 24),

            // Lesion Severity
            _buildFormSection(
              title: 'Lesion Severity',
              child: RadioGroup<String>(
                groupValue: lesionSeverity,
                onChanged: (value) {
                  if (value == null) return;
                  _handleLesionChange(value);
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('None'),
                      value: 'none',
                    ),
                    RadioListTile<String>(
                      title: const Text('Mild'),
                      value: 'mild',
                    ),
                    RadioListTile<String>(
                      title: const Text('Moderate'),
                      value: 'moderate',
                    ),
                    RadioListTile<String>(
                      title: const Text('Severe'),
                      value: 'severe',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Affected Areas
            _buildFormSection(
              title: 'Affected Areas',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Scalp',
                  'Face',
                  'Chest',
                  'Arms',
                  'Legs',
                  'Hands',
                  'Feet',
                  'Back',
                ].map((area) {
                  return FilterChip(
                    label: Text(area),
                    selected: affectedAreas.contains(area),
                    onSelected: (_) => _handleAreaToggle(area),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Sleep Quality
            _buildFormSection(
              title: 'Sleep Quality',
              trailing: _buildSleepQualityBadge(),
              child: _prefill != null &&
                      _prefill!.hasSleepQuality &&
                      !_sleepQualityOverridden
                  ? Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.wearableBlue.withValues(alpha:0.5),
                          width: 1.5,
                        ),
                        color: AppTheme.wearableBlue.withValues(alpha:0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomSliderWidget(
                        key: ValueKey('sleep_$sleepQuality'),
                        label: 'Sleep Quality (1-5)',
                        initialValue: sleepQuality,
                        min: 1,
                        max: 5,
                        onChanged: _handleSleepQualityChange,
                        activeTrackColor: AppTheme.wearableBlue,
                      ),
                    )
                  : CustomSliderWidget(
                      key: ValueKey('sleep_$sleepQuality'),
                      label: 'Sleep Quality (1-5)',
                      initialValue: sleepQuality,
                      min: 1,
                      max: 5,
                      onChanged: _handleSleepQualityChange,
                    ),
            ),
            const SizedBox(height: 24),

            // Sleep Disruption
            _buildFormSection(
              title: 'Sleep Disruption',
              trailing: _buildSleepDisruptionBadge(),
              child: _prefill != null &&
                      _prefill!.hasSleepDisruption &&
                      !_sleepDisruptionOverridden
                  ? Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.wearableBlue.withValues(alpha:0.5),
                          width: 1.5,
                        ),
                        color: AppTheme.wearableBlue.withValues(alpha:0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CheckboxListTile(
                        title: const Text('My sleep was disrupted'),
                        value: sleepDisruption,
                        onChanged: _handleSleepDisruptionChange,
                      ),
                    )
                  : CheckboxListTile(
                      title: const Text('My sleep was disrupted'),
                      value: sleepDisruption,
                      onChanged: _handleSleepDisruptionChange,
                    ),
            ),
            const SizedBox(height: 24),

            // Treatment today (optional)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Treatment today (optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Anything to note about your treatment today?',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TreatmentChip(
                          label: 'All good',
                          selected: _treatmentNoteAction == 'allGood',
                          onTap: () => _setTreatmentNoteAction('allGood'),
                        ),
                        _TreatmentChip(
                          label: 'Missed dose',
                          selected: _treatmentNoteAction == 'missedDose',
                          onTap: () => _setTreatmentNoteAction('missedDose'),
                        ),
                        _TreatmentChip(
                          label: 'Side effect',
                          selected: _treatmentNoteAction == 'sideEffect',
                          onTap: () => _setTreatmentNoteAction('sideEffect'),
                        ),
                        _TreatmentChip(
                          label: 'Changed dose',
                          selected: _treatmentNoteAction == 'changedDose',
                          onTap: () => _setTreatmentNoteAction('changedDose'),
                        ),
                        _TreatmentChip(
                          label: 'Stopped',
                          selected: _treatmentNoteAction == 'stopped',
                          onTap: () => _setTreatmentNoteAction('stopped'),
                        ),
                      ],
                    ),
                    if (_treatmentNoteAction == 'sideEffect' ||
                        _treatmentNoteAction == 'changedDose' ||
                        _treatmentNoteAction == 'stopped') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _treatmentNoteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: _treatmentNoteAction == 'sideEffect'
                              ? 'Optional: dryness, burning, nausea, etc.'
                              : 'Optional: what changed?',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Triggers today (collapsible card)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _triggersExpanded = !_triggersExpanded;
                        });
                      },
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Triggers today',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            _triggersExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _buildTriggerSummaryLabel(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding:
                            const EdgeInsets.only(top: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            ..._triggerCategories.map((cat) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.displayLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: cat.options
                                          .map((opt) {
                                        final id = opt.id.full;
                                        final selected =
                                            _selectedTriggerIds
                                                .contains(id);
                                        return FilterChip(
                                          label:
                                              Text(opt.displayLabel),
                                          selected: selected,
                                          onSelected: (_) =>
                                              _toggleTriggerSelection(
                                                  id),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: const InputDecoration(
                                labelText:
                                    'Other trigger (optional)',
                                hintText:
                                    'Anything else that seemed to affect your skin today?',
                                border: OutlineInputBorder(),
                                contentPadding:
                                    EdgeInsets.all(12),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _otherTriggerText = value;
                                });
                                _onAnyFieldChange();
                              },
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _triggersExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration:
                          const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notes
            _buildFormSection(
              title: 'Additional Notes',
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Any observations or notes you’d like to remember?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Done button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 40),
              ],
            ),
          ),
          // Auto-save status overlay - does not affect scroll layout
          if (showAutoSaveMessage)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: autoSaveStatus.contains('Saved')
                        ? Colors.green[100]
                        : autoSaveStatus.contains('Error')
                            ? Colors.red[100]
                            : Colors.blue[100],
                    border: Border(
                      bottom: BorderSide(
                        color: autoSaveStatus.contains('Saved')
                            ? Colors.green
                            : autoSaveStatus.contains('Error')
                                ? Colors.red
                                : Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Text(
                      autoSaveStatus,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: autoSaveStatus.contains('Saved')
                            ? Colors.green[800]
                            : autoSaveStatus.contains('Error')
                                ? Colors.red[800]
                                : Colors.blue[800],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TreatmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TreatmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}