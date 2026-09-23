import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dhealth/services/environmental_data_service.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/services/firestore_daily_log_service.dart';
import 'package:dhealth/screens/daily_log_screen.dart';
import 'package:dhealth/screens/reports_screen.dart';
import 'package:dhealth/screens/insights_screen.dart';
import 'package:dhealth/screens/recommendations_screen.dart';
import 'package:dhealth/screens/login_screen.dart';
import 'package:dhealth/screens/pro_questionnaire_screen.dart';
import 'package:dhealth/screens/settings/settings_screen.dart';
import 'package:dhealth/screens/urgent_care_screen.dart';
import 'package:dhealth/services/firestore_weekly_pulse_service.dart';
import 'package:dhealth/widgets/weekly_pulse_dialog.dart';
import 'package:dhealth/models/log_analytics.dart';
import 'package:dhealth/models/refined_risk_score_cache.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/data/disorder_registry.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/firestore_red_flag_acknowledgement_service.dart';
import 'package:dhealth/widgets/risk_badge_widget.dart';
import 'package:dhealth/widgets/emergency_red_flag_modal.dart';
import 'package:dhealth/widgets/urgent_red_flag_banner.dart';
import 'package:dhealth/widgets/weekly_stats_card.dart';
import 'package:dhealth/widgets/recent_logs_list.dart';
import 'package:dhealth/widgets/feature_flags_scope.dart';
import 'package:dhealth/widgets/trigger_insight_card.dart';
import 'package:dhealth/screens/insights/trigger_correlations_screen.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/models/risk_score_result.dart';
import 'package:dhealth/services/onboarding_prefs.dart';
import 'package:dhealth/services/notification_service.dart';
import 'package:dhealth/widgets/empty_state_widget.dart';
import 'package:dhealth/widgets/skeleton_widgets.dart';


import 'dart:io' show Platform;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.createDailyLogService});

  /// Test seam for startup-failure screens. Defaults to [DailyLogService.new].
  @visibleForTesting
  final DailyLogService Function()? createDailyLogService;

  @override
  State createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String selectedCondition = 'psoriasis';

  EnvironmentalDataService? _envService;
  DailyLogService? _dailyLogService;
  FirestoreDailyLogService? _firestoreService;

  Map<String, dynamic>? _envData;
  bool _isLoading = false;
  String? _errorMessage;

  bool _firebaseConnected = false;
  bool _servicesInitialized = false;
  String _initError = '';
  bool _isWeb = false;
  bool _weeklyPulseCheckDone = false;
  Future<List<TriggerProCorrelation>?>? _correlationsFuture;
  final RefinedRiskScoreCache _riskScoreCache = RefinedRiskScoreCache();

  @override
  void initState() {
    super.initState();
    _detectPlatform();
    _loadConditionFromPrefs();
    _initializeAllServices();
    NotificationService.onPayloadReceived = _handlePendingNotificationPayload;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNotificationPayload();
    });
  }

  @override
  void dispose() {
    NotificationService.onPayloadReceived = null;
    super.dispose();
  }

  void _handlePendingNotificationPayload() {
    final payload = NotificationService.consumePendingPayload();
    if (payload == null || !mounted) return;
    if (payload == NotificationService.payloadDaily) {
      _openDailyLogScreen();
    } else if (payload == NotificationService.payloadWeeklyPro) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProQuestionnaireScreen(
            condition: selectedCondition,
          ),
        ),
      );
    }
  }

  Future<void> _loadConditionFromPrefs() async {
    final condition = await OnboardingPrefs.getCondition();
    if (mounted) setState(() => selectedCondition = condition);
  }

  void _detectPlatform() {
    try {
      _isWeb = !Platform.isAndroid && !Platform.isIOS;
    } catch (e) {
      _isWeb = true;
    }
    debugPrint('Platform: ${_isWeb ? "WEB" : "MOBILE"}');
  }

  Future<void> _initializeAllServices() async {
    try {
      debugPrint('Starting service initialization...');

      // DailyLogService
      try {
        _dailyLogService =
            (widget.createDailyLogService ?? DailyLogService.new)();
        debugPrint('DailyLogService created');
      } catch (e) {
        debugPrint('Failed to create DailyLogService: $e');
        setState(() {
          _servicesInitialized = true;
          _initError = 'Critical: DailyLogService failed. Please restart.';
        });
        return;
      }

      // EnvironmentalDataService
      try {
        _envService = EnvironmentalDataService();
        debugPrint('EnvironmentalDataService created');
      } catch (e) {
        debugPrint('EnvironmentalDataService init failed: $e');
      }

      // FirestoreDailyLogService
      try {
        _firestoreService = FirestoreDailyLogService(userId: 'demo-user');
        debugPrint('FirestoreDailyLogService created');
      } catch (e) {
        debugPrint('FirestoreService init failed: $e');
        _firestoreService = null;
      }

      if (_dailyLogService == null) {
        debugPrint('DailyLogService is null - cannot continue');
        setState(() {
          _servicesInitialized = true;
          _initError =
              'Failed to initialize services. Please restart the app.';
        });
        return;
      }

      debugPrint('Essential services initialized, marking as ready');
      setState(() => _servicesInitialized = true);

      // Check Firebase connection
      if (_firestoreService != null) {
        try {
          final connected = await _firestoreService!.isConnected();
          setState(() => _firebaseConnected = connected);
          debugPrint('Firebase: ${connected ? "Connected" : "Offline"}');
        } catch (e) {
          debugPrint('Firebase connection check failed: $e');
          setState(() => _firebaseConnected = false);
        }

        try {
          await _syncLogsFromFirestore();
        } catch (e) {
          debugPrint('Firestore sync failed: $e');
        }
        _correlationsFuture = _loadCorrelations();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowWeeklyPulse();
          _maybeShowEmergencyRedFlagModal();
        });
      } else {
        debugPrint('Firestore service not available - skipping sync');
      }

      // Restore notification schedules for returning users (mobile only)
      if (!_isWeb) {
        try {
          final reminder = await OnboardingPrefs.getReminderTime();
          await NotificationService.scheduleDailyReminder(
            reminder.hour,
            reminder.minute,
          );
          final weeklyEnabled = await OnboardingPrefs.getWeeklyProReminderEnabled();
          if (weeklyEnabled) {
            await NotificationService.scheduleWeeklyProReminder();
          }
        } catch (e) {
          debugPrint('Restore notifications failed: $e');
        }
      }

      // Do not await location/weather on the startup path: Geolocator on
      // Android can stall the UI thread and surface an ANR. Kick off after
      // the first frame; manual Refresh still calls [_fetchEnvironmentalData].
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _envService == null) return;
        _fetchEnvironmentalData();
      });
    } catch (e) {
      debugPrint('Critical initialization error: $e');
      setState(() {
        _servicesInitialized = true;
        _initError = 'Critical Error: $e';
      });
    }
  }

  Future<List<TriggerProCorrelation>?> _loadCorrelations() async {
    final logs = _dailyLogService?.getLogs() ?? [];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || logs.isEmpty) return null;
    try {
      final proSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('proAssessments')
          .get();
      final pros = proSnap.docs
          .map((d) => ProAssessment.fromJson(d.data(), id: d.id))
          .toList();
      if (pros.isEmpty) return null;
      final correlations = TriggerProCorrelationEngine.correlate(logs, pros);
      if (correlations.isEmpty) return null;
      final top = correlations.first;
      if (top.r.abs() < 0.4 || top.weeks < 8) return null;
      return correlations;
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeShowEmergencyRedFlagModal() async {
    if (_dailyLogService == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final logs = _dailyLogService!.getLogs();
    if (logs.isEmpty) return;
    final disorder = DisorderRegistry.getDisorder(selectedCondition);
    final redFlags = InsightEngine.detectRedFlags(logs, disorder);
    if (!mounted) return;
    if (!FeatureFlagsScope.of(context).showRedFlags) return;
    final emergencyFlags =
        redFlags.where((f) => f.urgency == 'emergency').toList();
    if (emergencyFlags.isEmpty) return;
    final service =
        FirestoreRedFlagAcknowledgementService(userId: user.uid);
    for (final flag in emergencyFlags) {
      if (!mounted) return;
      await EmergencyRedFlagModal.show(
        context,
        flag: flag,
        acknowledgementService: service,
      );
    }
  }

  Future<void> _maybeShowWeeklyPulse() async {
    if (_weeklyPulseCheckDone) return;
    if (_firestoreService == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _weeklyPulseCheckDone = true;

    try {
      final pulseService = FirestoreWeeklyPulseService(userId: user.uid);
      final hasPulse = await pulseService.hasPulseForCurrentWeek();
      final allPulses = await pulseService.getPulsesForLastWeeks(52);
      final hasEverSubmitted = allPulses.isNotEmpty;

      if (!mounted) return;
      await WeeklyPulseDialog.showIfDue(
        context,
        pulseService: pulseService,
        condition: selectedCondition,
        hasPulseThisWeek: hasPulse,
        hasEverSubmittedPulse: hasEverSubmitted,
        onSaved: () => setState(() {}),
      );
    } catch (e) {
      _weeklyPulseCheckDone = false;
    }
  }

  Future<void> _showWeeklyPulseManually() async {
    if (_firestoreService == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final pulseService = FirestoreWeeklyPulseService(userId: user.uid);
      final hasPulse = await pulseService.hasPulseForCurrentWeek();
      final allPulses = await pulseService.getPulsesForLastWeeks(52);
      final hasEverSubmitted = allPulses.isNotEmpty;

      if (!mounted) return;
      await WeeklyPulseDialog.showIfDue(
        context,
        pulseService: pulseService,
        condition: selectedCondition,
        hasPulseThisWeek: hasPulse,
        hasEverSubmittedPulse: hasEverSubmitted,
        forceShow: true,
        onSaved: () => setState(() {}),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open check-in: $e')),
        );
      }
    }
  }

  Future<void> _syncLogsFromFirestore() async {
    try {
      if (_firestoreService == null || _dailyLogService == null) return;
      final logs = await _firestoreService!.getLogsForLastDays(30);
      for (final log in logs) {
        _dailyLogService!.addLog(log, quiet: true);
      }
      setState(() {});
      debugPrint('Synced ${logs.length} logs from Firestore');
    } catch (e) {
      debugPrint('Error syncing logs: $e');
    }
  }

  Future<void> _fetchEnvironmentalData() async {
    if (_envService == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _envService!.getAllEnvironmentalData();
      if (!mounted) return;
      setState(() {
        _envData = data;
      });
      debugPrint('Environmental data fetched');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      debugPrint('Error fetching environmental data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDailyLogScreen() async {
    if (_dailyLogService == null) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyLogScreen(
          dailyLogService: _dailyLogService!,
          firestoreService: _firestoreService,
          condition: selectedCondition,
        ),
      ),
    );
    // Rebuild so [_riskScoreCache] can see any log created/edited on that
    // screen. The cache itself only recomputes if log ids actually changed.
    if (mounted) setState(() {});
  }

  Widget _buildBodyWithRedFlagBanner() {
    final content = _selectedIndex == 0
        ? _buildHomeScreen()
        : _selectedIndex == 1
            ? ReportsScreen(firestoreService: _firestoreService)
            : _selectedIndex == 2
                ? (_dailyLogService != null
                    ? InsightsScreen(
                        dailyLogService: _dailyLogService!,
                        condition: selectedCondition,
                      )
                    : const EmptyStateWidget(
                        emoji: '💡',
                        title: 'Insights Tab',
                        description: 'Insights coming soon',
                      ))
                : (_dailyLogService != null
                    ? RecommendationsScreen(
                        selectedCondition: selectedCondition,
                        dailyLogService: _dailyLogService!,
                      )
                    : const EmptyStateWidget(
                        emoji: '🗒️',
                        title: 'Recommendations',
                        description: 'Loading...',
                      ));

    final logs = _dailyLogService?.getLogs() ?? [];
    final urgentFlags = logs.isEmpty
        ? <RedFlag>[]
        : InsightEngine.detectRedFlags(
            logs,
            DisorderRegistry.getDisorder(selectedCondition),
          ).where((f) => f.urgency == 'urgent').toList();

    if (!FeatureFlagsScope.of(context).showRedFlags || urgentFlags.isEmpty) {
      return content;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UrgentRedFlagBanner(
          urgentFlags: urgentFlags,
          acknowledgementService:
              FirestoreRedFlagAcknowledgementService(userId: user.uid),
          onActionLogged: () => setState(() {}),
        ),
        Expanded(child: content),
      ],
    );
  }

  static const _riskComponentLabels = {
    'itch': 'itch',
    'lesion': 'lesion severity',
    'extent': 'affected area',
    'stress': 'stress',
    'mood': 'mood',
    'sleep': 'sleep disruption',
    'env': 'environmental factors',
  };

  /// Single source of truth for band → badge type: [RiskScoreResult.band]
  /// (from [RiskScoreResult.scoreToBand], or forced 'urgent' on red-flag
  /// override). Do not re-derive the band from the raw score elsewhere.
  RiskBadgeType _riskBadgeType(String band) {
    switch (band) {
      case 'low':
        return RiskBadgeType.low;
      case 'moderate':
        return RiskBadgeType.medium;
      case 'high':
        return RiskBadgeType.high;
      case 'urgent':
        return RiskBadgeType.urgent;
      default:
        return RiskBadgeType.low;
    }
  }

  String _riskBandLabel(String band) {
    switch (band) {
      case 'low':
        return 'Low Risk';
      case 'moderate':
        return 'Moderate';
      case 'high':
        return 'High Risk';
      case 'urgent':
        return 'Urgent';
      default:
        return 'Low Risk';
    }
  }

  Color _riskBandColor(String band) {
    switch (band) {
      case 'low':
        return AppTheme.riskLow;
      case 'moderate':
        return AppTheme.riskMedium;
      case 'high':
        return AppTheme.riskHigh;
      case 'urgent':
        return AppTheme.riskUrgent;
      default:
        return AppTheme.riskLow;
    }
  }

  /// "43/100 — 20 from itch, 10 from sleep disruption, 8 from stress".
  /// Surfaces [RiskScoreResult.components] (already computed by
  /// RiskScoreCalculator) so the score is never shown as a bare number.
  String _riskBreakdownText(RiskScoreResult result) {
    final parts = <String, double>{
      for (final entry in result.components.entries)
        (_riskComponentLabels[entry.key] ?? entry.key): entry.value,
      if (result.trendModifier != 0) 'recent trend': result.trendModifier,
      if (result.triggerModifier != 0) 'trigger pattern': result.triggerModifier,
      if (result.wearableModifier != 0)
        'wearable data': result.wearableModifier.toDouble(),
    };
    final sorted = parts.entries.where((e) => e.value.round() != 0).toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    if (sorted.isEmpty) return '${result.finalScore}/100';
    final breakdown = sorted
        .map((e) => '${e.value.round()} from ${e.key}')
        .join(', ');
    return '${result.finalScore}/100 — $breakdown';
  }

  /// Static urgent-care guidance entry. Always shown, including on startup
  /// failure screens: must not read FeatureFlags (reference content, not
  /// computed interpretation).
  Widget _buildUrgentCareEntry() {
    return Card(
      key: const Key('homeUrgentCareEntry'),
      child: ListTile(
        leading: const Icon(
          Icons.health_and_safety_outlined,
          color: AppTheme.textSecondary,
        ),
        title: const Text('When to seek urgent care'),
        subtitle: const Text(
          'Warning signs that need prompt medical attention',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UrgentCareScreen(condition: selectedCondition),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (_dailyLogService == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: Text('DailyLogService not initialized')),
          const SizedBox(height: 16),
          _buildUrgentCareEntry(),
        ],
      );
    }

    final logs = _dailyLogService!.getLogs();
    final analytics = LogAnalytics(logs);
    final hasTodayLog = analytics.getTodayLog() != null;
    final riskResult = _riskScoreCache.getOrCompute(
      logs: logs,
      condition: selectedCondition,
      envData: _envData,
      compute: () => analytics.getRefinedRiskScore(
        selectedCondition,
        DisorderRegistry.getDisorder(selectedCondition),
        envData: _envData,
      ),
    );
    final todayRiskScore = riskResult.finalScore;
    final flags = FeatureFlagsScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Condition selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Your Condition',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: selectedCondition,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'psoriasis',
                        child: Text('Psoriasis'),
                      ),
                      DropdownMenuItem(
                        value: 'eczema',
                        child: Text('Atopic Dermatitis (Eczema)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCondition = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          _buildUrgentCareEntry(),
          const SizedBox(height: 16),

          // Risk card (hidden when showRiskScore is false; computation above still runs)
          if (hasTodayLog && flags.showRiskScore)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Today\'s Risk Score',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$todayRiskScore / 100',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        RiskBadgeWidget(
                          type: _riskBadgeType(riskResult.band),
                          label: _riskBandLabel(riskResult.band),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: todayRiskScore / 100,
                      minHeight: 8,
                      backgroundColor: AppTheme.surfaceAlt,
                      valueColor:
                          AlwaysStoppedAnimation(_riskBandColor(riskResult.band)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _riskBreakdownText(riskResult),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (riskResult.usedPersonalWeights)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Based on your last 90 days of data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (!hasTodayLog)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.edit, size: 32, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'No log for today yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _openDailyLogScreen,
                        child: const Text('Create Today\'s Log'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // TODO: weekly focus card goes here
          const SizedBox.shrink(),

          if (_dailyLogService!.getLogs().isNotEmpty)
            WeeklyStatsCard(analytics: analytics),
          const SizedBox(height: 16),

          // Trigger insight card (only if significant correlation)
          if (flags.showTriggerInsights && _correlationsFuture != null)
            FutureBuilder<List<TriggerProCorrelation>?>(
              future: _correlationsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data == null ||
                    snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                final correlations = snapshot.data!;
                final top = correlations.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TriggerInsightCard(
                      correlation: top,
                      condition: selectedCondition,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final screen =
                              await TriggerCorrelationsScreen.fromCurrentUser(
                            context,
                            selectedCondition,
                          );
                          if (!context.mounted) return;
                          if (screen != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => screen,
                              ),
                            );
                          }
                        },
                        child: const Text('See all insights â†’'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

          // Environmental data
          if (_isLoading)
            const SkeletonStatsRow()
          else if (_errorMessage != null)
            Card(
              color: AppTheme.dangerColor.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error Loading Data',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dangerColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.dangerColor),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _fetchEnvironmentalData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_envData != null)
            Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weather',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(_envData!['weather']['main']['temp'] as num).toInt()} C',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  (_envData!['weather']['weather'][0]
                                              ['description'] as String)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Humidity: ${_envData!['weather']['main']['humidity']}%',
                                ),
                                Text(
                                  'Wind: ${(_envData!['weather']['wind']['speed'] as num).toInt()} m/s',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Lat: ${_envData!['latitude']?.toStringAsFixed(4)}',
                        ),
                        Text(
                          'Lon: ${_envData!['longitude']?.toStringAsFixed(4)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _fetchEnvironmentalData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          RecentLogsList(
            logs: analytics.getLogsFromLastDays(7),
            onStartCheckIn: _openDailyLogScreen,
          ),
          const SizedBox(height: 16),

          // Daily Symptom Log section - enabled on web too
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Symptom Log',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Track your symptoms daily to identify triggers and patterns',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openDailyLogScreen,
                      child: const Text('Start Daily Check-In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Patient-only main experience.
    return _buildPatientMain(context);
  }

  Widget _buildPatientMain(BuildContext context) {
    if (!_servicesInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Siequi'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Initializing Siequi...'),
              if (_initError.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error: $_initError',
                    style: const TextStyle(
                        color: AppTheme.dangerColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_initError.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Siequi - Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: AppTheme.dangerColor),
              const SizedBox(height: 16),
              const Text(
                'Initialization Failed',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _initError,
                  style: const TextStyle(color: AppTheme.dangerColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _servicesInitialized = false;
                    _initError = '';
                  });
                  _initializeAllServices();
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildUrgentCareEntry(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Siequi',
          style: AppTheme.wordmarkStyle.copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeatureFlagsScope(
                      flags: FeatureFlagsScope.of(context),
                      child: SettingsScreen(
                        initialCondition: selectedCondition,
                        onConditionChanged: () {
                          _loadConditionFromPrefs();
                        },
                      ),
                    ),
                  ),
                );
              } else if (value == 'weeklyPulse') {
                await _showWeeklyPulseManually();
              } else if (value == 'pros') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProQuestionnaireScreen(
                      condition: selectedCondition,
                    ),
                  ),
                );
              } else if (value == 'logout') {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged out')),
                  );
                  setState(() => _firebaseConnected = false);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'weeklyPulse',
                child: ListTile(
                  leading: Icon(Icons.favorite_border),
                  title: Text('Weekly check-in'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'pros',
                child: ListTile(
                  leading: Icon(Icons.assignment),
                  title: Text('Questionnaires (POEM / DLQI)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Tooltip(
                message: _firebaseConnected
                    ? 'Firestore connected'
                    : (_firestoreService == null
                        ? 'Firestore not initialized'
                        : 'Firestore offline'),
                // Icon shape (not just color) carries the status, so this
                // isn't a color-only indicator.
                child: Icon(
                  _firebaseConnected
                      ? Icons.cloud_done
                      : (_firestoreService == null
                          ? Icons.cloud_off
                          : Icons.cloud_queue),
                  size: 18,
                  color: _firebaseConnected
                      ? AppTheme.accentColor
                      : (_firestoreService == null
                          ? AppTheme.dangerColor
                          : AppTheme.warningColor),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBodyWithRedFlagBanner(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          debugPrint('Tapped index: $index');
          setState(() {
            _selectedIndex = index;
          });
          debugPrint('_selectedIndex updated to: $_selectedIndex');
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.file_download),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.recommend),
            label: 'Recommendations',
          ),
        ],
      ),
    );
  }
}
