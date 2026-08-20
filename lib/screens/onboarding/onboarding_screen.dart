import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/utils/abha_id_formatter.dart';
import 'package:dhealth/services/onboarding_prefs.dart';
import 'package:dhealth/services/notification_service.dart';
import 'package:dhealth/services/firestore_user_profile_service.dart';
import 'package:dhealth/models/medication_profile.dart';
import 'package:dhealth/services/medication_profile_service.dart';

/// First-launch onboarding flow. Shown once for new users.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String? _selectedCondition;
  DateTime? _dateOfBirth;
  final TextEditingController _abhaIdController = TextEditingController();
  int _reminderHour = OnboardingPrefs.defaultReminderHour;
  int _reminderMinute = OnboardingPrefs.defaultReminderMinute;
  MedicationTreatmentType _treatmentType = MedicationTreatmentType.none;
  final TextEditingController _medicationNameController =
      TextEditingController();

  @override
  void dispose() {
    _abhaIdController.dispose();
    _medicationNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_currentPage == 4) {
      await _handleTreatmentStepContinue();
      return;
    }
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    await OnboardingPrefs.setCondition(_selectedCondition ?? 'psoriasis');
    await OnboardingPrefs.setReminderTime(_reminderHour, _reminderMinute);
    await NotificationService.scheduleDailyReminder(_reminderHour, _reminderMinute);
    await NotificationService.scheduleWeeklyProReminder();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirestoreUserProfileService.saveCondition(
        uid,
        _selectedCondition ?? 'psoriasis',
      );
      await FirestoreUserProfileService.saveDateOfBirth(uid, _dateOfBirth);
      await FirestoreUserProfileService.saveAbhaId(
        uid,
        _abhaIdController.text.trim().isEmpty
            ? null
            : _abhaIdController.text.trim(),
      );
    }

    await OnboardingPrefs.setComplete();
    if (mounted) widget.onComplete();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked != null && mounted) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 1:
        return _selectedCondition != null;
      default:
        return true;
    }
  }

  String get _ctaLabel {
    switch (_currentPage) {
      case 0:
        return 'Get started →';
      case 1:
        return 'Continue →';
      case 2:
        return 'Continue →';
      case 3:
        return 'Continue →';
      case 4:
        return 'Sounds good →';
      case 5:
        return 'Start logging →';
      default:
        return 'Continue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Back chevron (pages 2–4)
            if (_currentPage > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousPage,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  if (mounted) setState(() => _currentPage = i);
                },
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildProfilePage(),
                  _buildTreatmentPage(),
                  _buildPage4(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final active = i == _currentPage;
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? AppTheme.primary
                              : AppTheme.borderColor,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canProceed ? _nextPage : null,
                      child: Text(_ctaLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Your skin, tracked clearly.',
            style: GoogleFonts.fraunces(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'DHealth helps you understand what affects your skin day to day, '
            'and gives your doctor a clear picture at every visit.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '🌿',
                  style: TextStyle(fontSize: 48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'What condition are you managing?',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ConditionCard(
            title: 'Psoriasis',
            description:
                'Thick, scaly patches. Often affects scalp, elbows, knees.',
            selected: _selectedCondition == 'psoriasis',
            onTap: () => setState(() => _selectedCondition = 'psoriasis'),
          ),
          const SizedBox(height: AppSpacing.md),
          _ConditionCard(
            title: 'Eczema',
            description:
                'Itchy, inflamed skin. Often triggered by stress and environment.',
            selected: _selectedCondition == 'eczema',
            onTap: () => setState(() => _selectedCondition = 'eczema'),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            "Here's all we ask",
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _InfoRow(
            icon: '✅',
            text: '30-second daily check-in — mood, itch, sleep, stress',
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: '📋',
            text: 'Weekly questionnaire — POEM or DLQI (2 minutes)',
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: '💬',
            text: 'Optional notes — triggers, observations',
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            "That's it. No photos, no devices required. The more consistently "
            'you log, the more useful your insights become.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    final dobDisplay = _dateOfBirth != null
        ? DateFormat('d MMM yyyy').format(_dateOfBirth!)
        : 'Not set';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'A few optional details',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'These help your reports stay aligned with health data standards. '
            "You can skip them if you'd like.",
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            title: const Text('Date of birth (optional)'),
            subtitle: Text(dobDisplay),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final now = DateTime.now();
              final initial = _dateOfBirth ?? DateTime(now.year - 30, 1, 1);
              final picked = await showDatePicker(
                context: context,
                initialEntryMode: DatePickerEntryMode.input,
                initialDate: initial.isAfter(now) ? now : initial,
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (picked != null && mounted) {
                setState(() {
                  _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
                });
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _abhaIdController,
            maxLength: 17,
            keyboardType: TextInputType.number,
            inputFormatters: const [
              AbhaIdFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'ABHA ID (optional)',
              helperText: 'Your Ayushman Bharat Health Account number',
              hintText: 'XX-XXXX-XXXX-XXXX',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildPage4() {
    final h = _reminderHour == 0
        ? 12
        : _reminderHour > 12
            ? _reminderHour - 12
            : _reminderHour;
    final period = _reminderHour >= 12 ? 'PM' : 'AM';
    final hourStr = '$h:${_reminderMinute.toString().padLeft(2, '0')} $period';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'When should we remind you?',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            title: Text(
              hourStr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "We'll send you a daily nudge at this time. "
            'You can change it in settings.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Your current treatment',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Skip'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Helps your doctor understand your symptom history',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...MedicationTreatmentType.values.map((type) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _treatmentType = type;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _treatmentType == type
                        ? AppTheme.primary.withValues(alpha:0.04)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _treatmentType == type
                          ? AppTheme.primary
                          : AppTheme.borderColor,
                      width: _treatmentType == type ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          type.displayLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _treatmentType == type
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_treatmentType == type)
                        const Icon(
                          Icons.check_circle,
                          color: AppTheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _medicationNameController,
            maxLength: 60,
            keyboardType: TextInputType.text,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Medication name (optional)',
              hintText:
                  'e.g. methotrexate, dupilumab, betamethasone',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _handleTreatmentStepContinue() async {
    final selectedType = _treatmentType;
    final name = _medicationNameController.text.trim();

    if (selectedType == MedicationTreatmentType.none && name.isEmpty) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final profile = MedicationProfile(
        uid: uid,
        treatmentType: selectedType,
        medicationName: name.isEmpty ? null : name,
        startDate: null,
        updatedAt: DateTime.now(),
      );
      try {
        await MedicationProfileService().saveProfile(profile);
      } catch (_) {}
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimaryColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
