import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:dhealth/services/onboarding_prefs.dart';
import 'package:dhealth/services/notification_service.dart';
import 'package:dhealth/services/firestore_user_profile_service.dart';
import 'package:dhealth/services/firestore_daily_log_service.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/report_generator_service.dart';
import 'package:dhealth/services/fhir_bundle_generator.dart';
import 'package:dhealth/services/user_data_delete_service.dart';
import 'package:dhealth/services/firestore_medication_exception_service.dart';
import 'package:dhealth/services/firestore_flare_event_service.dart';
import 'package:dhealth/screens/wearables/connect_devices_screen.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/medication_profile.dart';
import 'package:dhealth/services/medication_profile_service.dart';
import 'package:dhealth/utils/abha_id_formatter.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/utils/file_download_helper.dart';

const _sectionHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: AppTheme.textMuted,
  letterSpacing: 0.08,
);

/// Settings screen with notification, condition, data and privacy controls.
class SettingsScreen extends StatefulWidget {
  final String initialCondition;
  final VoidCallback? onConditionChanged;

  const SettingsScreen({
    super.key,
    this.initialCondition = 'psoriasis',
    this.onConditionChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _reminderHour = OnboardingPrefs.defaultReminderHour;
  int _reminderMinute = OnboardingPrefs.defaultReminderMinute;
  bool _weeklyProEnabled = true;
  String _condition = 'psoriasis';
  String _appVersion = '';
  MedicationProfile? _medicationProfile;
  DateTime? _dateOfBirth;
  String? _abhaId;

  @override
  void initState() {
    super.initState();
    _condition = widget.initialCondition;
    _loadPrefs();
    _loadVersion();
    _loadMedicationProfile();
    _loadProfileDemographics();
  }

  Future<void> _loadPrefs() async {
    final time = await OnboardingPrefs.getReminderTime();
    final weekly = await OnboardingPrefs.getWeeklyProReminderEnabled();
    if (mounted) {
      setState(() {
        _reminderHour = time.hour;
        _reminderMinute = time.minute;
        _weeklyProEnabled = weekly;
      });
    }
  }

  Future<void> _loadMedicationProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await MedicationProfileService().getProfile(user.uid);
      if (mounted) {
        setState(() {
          _medicationProfile = profile;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProfileDemographics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile =
          await FirestoreUserProfileService.getProfile(user.uid) ?? {};
      final dobRaw = profile['dateOfBirth'];
      DateTime? dob;
      if (dobRaw is String && dobRaw.isNotEmpty) {
        try {
          dob = DateFormat('yyyy-MM-dd').parse(dobRaw);
        } catch (_) {
          dob = null;
        }
      }
      if (mounted) {
        setState(() {
          _dateOfBirth = dob;
          _abhaId = (profile['abhaId'] as String?)?.trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (_) {}
  }

  String get _formattedReminderTime {
    final h = _reminderHour == 0 ? 12 : _reminderHour > 12 ? _reminderHour - 12 : _reminderHour;
    final period = _reminderHour >= 12 ? 'PM' : 'AM';
    return '$h:${_reminderMinute.toString().padLeft(2, '0')} $period';
  }

  String get _conditionDisplay => _condition == 'eczema' ? 'Eczema' : 'Psoriasis';

  String get _treatmentDisplay {
    if (_medicationProfile == null ||
        _medicationProfile!.treatmentType == MedicationTreatmentType.none) {
      return 'Not set';
    }
    final base = _medicationProfile!.treatmentType.displayLabel;
    final name = _medicationProfile!.medicationName?.trim();
    if (name == null || name.isEmpty) {
      return base;
    }
    return '$base ($name)';
  }

  String get _dobDisplay {
    if (_dateOfBirth == null) return 'Not set';
    return DateFormat('d MMM yyyy').format(_dateOfBirth!);
  }

  String get _abhaDisplay => (_abhaId == null || _abhaId!.trim().isEmpty)
      ? 'Not set'
      : _abhaId!.trim();

  Future<void> _pickDailyReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
    await OnboardingPrefs.setReminderTime(_reminderHour, _reminderMinute);
    try {
      await NotificationService.scheduleDailyReminder(_reminderHour, _reminderMinute);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily reminder time updated')),
      );
    }
  }

  Future<void> _toggleWeeklyPro(bool value) async {
    setState(() => _weeklyProEnabled = value);
    await OnboardingPrefs.setWeeklyProReminderEnabled(value);
    try {
      if (value) {
        await NotificationService.scheduleWeeklyProReminder();
      } else {
        await NotificationService.cancelWeeklyProReminder();
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Weekly questionnaire reminder enabled' : 'Weekly questionnaire reminder disabled',
          ),
        ),
      );
    }
  }

  Future<void> _pickDateOfBirth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Sign in to edit your date of birth.');
      return;
    }
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 30, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.input,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    final normalized = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _dateOfBirth = normalized;
    });
    try {
      await FirestoreUserProfileService.saveDateOfBirth(user.uid, normalized);
    } catch (_) {}
  }

  Future<void> _showAbhaEditor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Sign in to edit your ABHA ID.');
      return;
    }
    final controller = TextEditingController(text: _abhaId ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ABHA ID',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Your Ayushman Bharat Health Account number',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: controller,
                    maxLength: 17,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      AbhaIdFormatter(),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'XX-XXXX-XXXX-XXXX',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: () async {
                          final value = controller.text.trim();
                          setState(() {
                            _abhaId = value.isEmpty ? null : value;
                          });
                          try {
                            await FirestoreUserProfileService.saveAbhaId(
                              user.uid,
                              _abhaId,
                            );
                          } catch (_) {}
                          if (!ctx.mounted) return;
                          if (Navigator.canPop(ctx)) {
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        setState(() {
                          _abhaId = null;
                        });
                        try {
                          await FirestoreUserProfileService.saveAbhaId(
                            user.uid,
                            null,
                          );
                        } catch (_) {}
                        if (!ctx.mounted) return;
                        if (Navigator.canPop(ctx)) {
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Clear ABHA ID'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  void _showConditionPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Psoriasis'),
              onTap: () {
                Navigator.pop(ctx);
                _updateCondition('psoriasis');
              },
            ),
            ListTile(
              title: const Text('Eczema'),
              onTap: () {
                Navigator.pop(ctx);
                _updateCondition('eczema');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCondition(String condition) async {
    setState(() => _condition = condition);
    await OnboardingPrefs.setCondition(condition);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirestoreUserProfileService.saveCondition(uid, condition);
      } catch (_) {}
    }
    widget.onConditionChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Condition updated to $_conditionDisplay')),
      );
    }
  }

  void _showTreatmentEditor() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Sign in to edit your treatment.');
      return;
    }
    final initialType =
        _medicationProfile?.treatmentType ?? MedicationTreatmentType.none;
    final initialName = _medicationProfile?.medicationName ?? '';
    final controller = TextEditingController(text: initialName);
    var selectedType = initialType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current treatment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Update what you are currently on. This helps your doctor interpret your symptom history.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ...MedicationTreatmentType.values.map((type) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setModalState(() {
                                selectedType = type;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedType == type
                                      ? AppTheme.primary
                                      : AppTheme.borderColor,
                                  width: selectedType == type ? 2 : 1,
                                ),
                                color: selectedType == type
                                    ? AppTheme.primary.withValues(alpha:0.04)
                                    : AppTheme.surfaceColor,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      type.displayLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            selectedType == type
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (selectedType == type)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.primary,
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: controller,
                        maxLength: 60,
                        keyboardType: TextInputType.text,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Medication name (optional)',
                          hintText:
                              'e.g. methotrexate, dupilumab, betamethasone',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ElevatedButton(
                            onPressed: () async {
                              final name = controller.text.trim();
                              final profile = MedicationProfile(
                                uid: user.uid,
                                treatmentType: selectedType,
                                medicationName:
                                    name.isEmpty ? null : name,
                                startDate: _medicationProfile?.startDate,
                                updatedAt: DateTime.now(),
                              );
                              try {
                                await MedicationProfileService()
                                    .saveProfile(profile);
                                if (mounted) {
                                  setState(() {
                                    _medicationProfile = profile;
                                  });
                                }
                              } catch (_) {}
                              if (!ctx.mounted) return;
                              if (Navigator.canPop(ctx)) {
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            final profile = MedicationProfile(
                              uid: user.uid,
                              treatmentType: MedicationTreatmentType.none,
                              medicationName: null,
                              startDate: _medicationProfile?.startDate,
                              updatedAt: DateTime.now(),
                            );
                            try {
                              await MedicationProfileService()
                                  .saveProfile(profile);
                              if (mounted) {
                                setState(() {
                                  _medicationProfile = profile;
                                });
                              }
                            } catch (_) {}
                            if (!ctx.mounted) return;
                            if (Navigator.canPop(ctx)) {
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('Remove treatment'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  Future<void> _downloadMyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Sign in to download your data.');
      return;
    }
    _showSnackBar('Generating export...');
    try {
      // #region agent log
      try {
        final logFile = File('debug-210858.log');
        final logEntry = <String, dynamic>{
          'sessionId': '210858',
          'runId': 'pre-fix',
          'hypothesisId': 'SET-A',
          'location': 'settings_screen.dart:_downloadMyData',
          'message': 'downloadMyData_started',
          'data': {
            'uid': user.uid,
          },
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        logFile.writeAsStringSync(
          '${jsonEncode(logEntry)}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
      final logService = FirestoreDailyLogService(userId: user.uid);
      final logs = await logService.getLogsForLastDays(365);
      final pulseSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('weeklyPulses')
          .get();
      final pulses = pulseSnap.docs
          .map((d) => WeeklySelfEfficacyPulse.fromJson(d.data(), id: d.id))
          .toList();
      final proSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('proAssessments')
          .get();
      final pros = proSnap.docs
          .map((d) => ProAssessment.fromJson(d.data(), id: d.id))
          .toList();
      MedicationProfile? medicationProfile;
      try {
        medicationProfile =
            await MedicationProfileService().getProfile(user.uid);
      } catch (_) {}

      if (logs.isEmpty) {
        _showSnackBar('No logs to export.');
        return;
      }

      final sortedLogs = List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
      final startDate = sortedLogs.first.date;
      final endDate = sortedLogs.last.date;
      final patientName = user.displayName ?? 'Patient';
      final correlations = TriggerProCorrelationEngine.correlate(sortedLogs, pros);
      final medicationExceptions = await FirestoreMedicationExceptionService()
          .getForLastDays(days: 365, uidOverride: user.uid);
      final flareEvents =
          await FirestoreFlareEventService(userId: user.uid).getForLastDays(
        days: 365,
      );

      final doc = await ReportGeneratorService.generateHealthReport(
        patientName: patientName,
        condition: _condition,
        logs: sortedLogs,
        startDate: startDate,
        endDate: endDate,
        medicationProfile: medicationProfile,
        medicationExceptions:
            medicationExceptions.isNotEmpty ? medicationExceptions : null,
        flareEvents: flareEvents.isNotEmpty ? flareEvents : null,
        weeklyPulses: pulses.isNotEmpty ? pulses : null,
        proAssessments: pros.isNotEmpty ? pros : null,
        triggerProCorrelations: correlations.isNotEmpty ? correlations : null,
        patientDateOfBirth: _dateOfBirth,
        patientAbhaId: _abhaId,
      );

      final pdfBytes = await doc.save();
      await saveBytesToFile(
        pdfBytes,
        'dhealth_report_${user.uid}.pdf',
        mimeType: 'application/pdf',
      );

      final bundle = FHIRBundleGenerator.generateFHIRBundle(
        patientId: user.uid,
        patientName: patientName,
        condition: _condition,
        logs: sortedLogs,
        reportDate: DateTime.now(),
        medicationExceptions:
            medicationExceptions.isNotEmpty ? medicationExceptions : null,
        flareEvents: flareEvents.isNotEmpty ? flareEvents : null,
      );
      final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);
      final fhirBytes = utf8.encode(jsonStr);
      await saveBytesToFile(
        fhirBytes,
        'dhealth_fhir_${user.uid}.json',
        mimeType: 'application/json',
      );

      // #region agent log
      try {
        final logFile = File('debug-210858.log');
        final logEntry = <String, dynamic>{
          'sessionId': '210858',
          'runId': 'pre-fix',
          'hypothesisId': 'SET-B',
          'location': 'settings_screen.dart:_downloadMyData',
          'message': 'downloadMyData_completed',
          'data': {
            'logCount': logs.length,
            'pulseCount': pulses.length,
            'proCount': pros.length,
          },
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        logFile.writeAsStringSync(
          '${jsonEncode(logEntry)}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion

      if (mounted) {
        _showSnackBar(
          'Exported: PDF and FHIR bundle saved',
        );
      }
    } catch (e) {
      // #region agent log
      try {
        final logFile = File('debug-4d8c79.log');
        final logEntry = <String, dynamic>{
          'sessionId': '4d8c79',
          'runId': 'pre-fix',
          'hypothesisId': 'SET-C',
          'location': 'settings_screen.dart:_downloadMyData',
          'message': 'downloadMyData_error',
          'data': {
            'error': e.toString(),
          },
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        logFile.writeAsStringSync(
          '${jsonEncode(logEntry)}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion

      if (mounted) _showSnackBar('Export failed: $e');
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Not signed in.');
      return;
    }

    _showSnackBar('Deleting your data...');
    try {
      await UserDataDeleteService.deleteAllUserData(user.uid);
      await user.delete();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnackBar('Account deletion failed: ${e.message}');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          if (!kIsWeb) ...[
            _sectionHeader('NOTIFICATIONS'),
            ListTile(
              title: const Text('Daily reminder time'),
              subtitle: Text(_formattedReminderTime),
              trailing: const Icon(Icons.edit),
              onTap: _pickDailyReminderTime,
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Weekly questionnaire reminder'),
              subtitle: const Text('POEM / DLQI every Sunday at 10:00 AM'),
              value: _weeklyProEnabled,
              onChanged: _toggleWeeklyPro,
            ),
            const Divider(height: 1),
          ],
          _sectionHeader('MY CONDITION'),
          ListTile(
            title: const Text('Condition'),
            subtitle: Text(_conditionDisplay),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showConditionPicker,
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Current treatment'),
            subtitle: Text(_treatmentDisplay),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showTreatmentEditor,
          ),
          const Divider(height: 1),
          _sectionHeader('PROFILE'),
          ListTile(
            title: const Text('Date of birth'),
            subtitle: Text(_dobDisplay),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDateOfBirth,
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('ABHA ID'),
            subtitle: Text(_abhaDisplay),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAbhaEditor,
          ),
          const Divider(height: 1),
          _sectionHeader('DATA & PRIVACY'),
          ListTile(
            title: const Text('Connected devices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConnectDevicesScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Download my data'),
            subtitle: const Text('Export PDF and FHIR bundle'),
            trailing: const Icon(Icons.download),
            onTap: _downloadMyData,
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              'Delete my account',
              style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.w600),
            ),
            trailing: Icon(Icons.delete_forever, color: AppTheme.dangerColor),
            onTap: _deleteAccount,
          ),
          const Divider(height: 1),
          _sectionHeader('ABOUT'),
          ListTile(
            title: const Text('App version'),
            trailing: Text(_appVersion.isEmpty ? '…' : _appVersion),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
            child: Text(
              'DHealth is a tracking and education tool. It does not provide '
              'medical diagnoses or treatment recommendations.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
      child: Text(label.toUpperCase(), style: _sectionHeaderStyle),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool get _confirmed => _controller.text == 'DELETE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete my account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will permanently delete all your data. This action cannot be undone.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: Text('Delete', style: TextStyle(color: AppTheme.dangerColor)),
        ),
      ],
    );
  }
}
