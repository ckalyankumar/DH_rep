import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhealth/utils/responsive.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/services/environmental_data_service.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/services/firestore_daily_log_service.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/data/disorder_registry.dart';
import 'package:dhealth/screens/daily_log_screen.dart';
import 'package:dhealth/screens/reports_screen.dart';
import 'package:dhealth/screens/insights_screen.dart';
import 'package:dhealth/screens/login_screen.dart';
import 'package:dhealth/screens/share_with_doctor_screen.dart';
import 'package:dhealth/models/log_analytics.dart';
import 'package:dhealth/models/log_density_confidence.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/services/firestore_pro_assessment_service.dart';
import 'package:dhealth/services/doctor_patient_link_service.dart';
import 'package:dhealth/services/pro_alert_dismissal_service.dart';
import 'package:dhealth/widgets/risk_badge_widget.dart';
import 'package:dhealth/widgets/weekly_stats_card.dart';
import 'package:dhealth/widgets/recent_logs_list.dart';
import 'package:dhealth/widgets/wearable_dashboard_widget.dart';
import 'package:dhealth/widgets/clinical_note_widget.dart'
    show ClinicalNoteType, ClinicalNoteWidget, showWhenToSeeDoctorModal;
import 'package:dhealth/widgets/skeleton_widgets.dart';
import 'package:dhealth/widgets/weekly_focus_card.dart';
import 'package:dhealth/services/flare_detection_service.dart';
import 'package:dhealth/models/flare_candidate.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// HOME SCREEN - CLINICAL DASHBOARD
/// 
/// Features:
/// - Real-time flare risk assessment
/// - Red flag detection with emergency alerts
/// - Environmental trigger tracking
/// - Clinical insights integration
/// - Direct links to clinical evidence
/// ═══════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCondition = 'psoriasis';
  late EnvironmentalDataService _envService;
  late DailyLogService _dailyLogService;
  late FirestoreDailyLogService _firestoreService;

  FirestoreProAssessmentService? _proService;
  ProTrajectoryAlert? _proAlert;
  bool _proAlertDismissed = false;
  final ProAlertDismissalService _dismissalService = ProAlertDismissalService();
  List<ProAssessment> _proAssessments = [];

  Map<String, dynamic>? _envData;
  bool _isLoading = false;
  String? _errorMessage;
  bool _firebaseConnected = false;
  FlareCandidate? _pendingFlareCandidate;

  @override
  void initState() {
    super.initState();
    _envService = EnvironmentalDataService();
    _dailyLogService = DailyLogService();
    _firestoreService = FirestoreDailyLogService(userId: 'demo-user');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _proService = FirestoreProAssessmentService(userId: uid);
    }
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Check Firebase connection
    final connected = await _firestoreService.isConnected();
    setState(() => _firebaseConnected = connected);

    // Sync Firestore logs to local memory
    await _syncLogsFromFirestore();

    // Detect flare candidates (best-effort; requires auth)
    await _detectFlareCandidate();

    // Load any PRO trajectory alert for current condition
    await _loadProTrajectoryAlert();

    // Fetch environmental data
    await _fetchEnvironmentalData();
  }

  Future<void> _syncLogsFromFirestore() async {
    try {
      final logs = await _firestoreService.getLogsForLastDays(30);
      for (final log in logs) {
        _dailyLogService.addLog(log, quiet: true);
      }
      setState(() {});
      debugPrint('✅ Synced ${logs.length} logs from Firestore');
    } catch (e) {
      debugPrint('❌ Error syncing logs: $e');
    }
  }

  Future<void> _detectFlareCandidate() async {
    try {
      final logs = _dailyLogService.getLogs();
      final detector = FlareDetectionService();
      final candidate = await detector.detectCandidateFromRecentLogs(logs);
      if (!mounted) return;
      setState(() => _pendingFlareCandidate = candidate);
    } catch (_) {
      // Non-blocking.
    }
  }

  Future<void> _handleFlareCandidateResponse(
    FlareCandidate candidate,
    FlareCandidateResponse response,
  ) async {
    try {
      final detector = FlareDetectionService();
      await detector.respondToCandidate(candidate, response: response);
      if (!mounted) return;
      setState(() => _pendingFlareCandidate = null);
    } catch (_) {
      // Non-blocking.
    }
  }

  Future<void> _logPatientInitiatedFlare() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    try {
      final detector = FlareDetectionService();
      await detector.logPatientInitiatedFlare(onsetDate: DateTime.now());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flare logged.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log flare: $e')),
      );
    }
  }

  Future<void> _loadProTrajectoryAlert() async {
    final service = _proService;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (service == null || currentUser == null) return;

    try {
      final type = selectedCondition.toLowerCase() == 'eczema'
          ? ProAssessmentType.poem
          : ProAssessmentType.dlqi;
      final pros = await service.getAssessments(
        type: type,
        condition: selectedCondition,
        days: 180,
      );
      final alert = ProTrajectoryAlert.detectTrajectory(
        pros,
        type: type,
      );

      // Respect dismissal: resurface only if new assessment was added
      // after last dismissal or 7 days have passed.
      DateTime? lastDismissed =
          await _dismissalService.getLastDismissedAt('proTrajectory');
      bool shouldShow = alert != null;
      if (alert != null && lastDismissed != null) {
        final newestAssessmentDate =
            pros.isNotEmpty ? pros.last.date : alert.toDate;
        final hasNewAssessment = newestAssessmentDate.isAfter(lastDismissed);
        final sevenDaysPassed =
            DateTime.now().difference(lastDismissed).inDays >= 7;
        shouldShow = hasNewAssessment || sevenDaysPassed;
      }

      if (!mounted) return;
      setState(() {
        _proAlert = shouldShow ? alert : null;
        _proAlertDismissed = !shouldShow;
        _proAssessments = pros;
      });
    } catch (_) {
      // Best-effort; do not block home if PRO fetch fails.
    }
  }

  Future<void> _fetchEnvironmentalData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _envService.getAllEnvironmentalData();
      setState(() {
        _envData = data;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleShareWithDoctor(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final linkService = DoctorPatientLinkService();
    final links = await linkService.getLinksForPatient(user.uid);
    if (!context.mounted) return;
    final hasAnyDoctor = links.isNotEmpty;

    if (!hasAnyDoctor) {
      // Gently prompt to add a doctor before navigating.
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add your dermatologist?'),
          content: const Text(
            'To share this pattern directly, first add your dermatologist\'s email. '
            'You can still generate a report afterwards.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add email'),
            ),
          ],
        ),
      );

      if (!context.mounted) return;
      if (proceed == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShareWithDoctorScreen()),
        );
      }
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportsScreen(
          firestoreService: _firestoreService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _dailyLogService.getLogs();
    final analytics = LogAnalytics(logs);
    final todayRiskScore = analytics.getTodayRiskScore();
    final logDensity = LogDensityConfidence.forLast7Days(logs);
    final recent30DayLogs = analytics.getLogsFromLastDays(30);

    // Detect red flags
    final disorder = DisorderRegistry.getDisorder(selectedCondition);
    final redFlags = logs.isNotEmpty
        ? InsightEngine.detectRedFlags(logs, disorder)
        : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏥 DHealth - Clinical Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Tooltip(
                message: _firebaseConnected
                    ? '✓ Firestore connected'
                    : '✗ Firestore offline',
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _firebaseConnected ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════════════════════
            // SECTION 1: CONDITION SELECTION
            // ═══════════════════════════════════════════════════════════

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
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
                    const SizedBox(height: AppSpacing.md),
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
                          _loadProTrajectoryAlert();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 2: PRO TRAJECTORY (QUALITY-OF-LIFE) ALERT
            // ═══════════════════════════════════════════════════════════

            if (_proAlert != null && !_proAlertDismissed) ...[
              Card(
                color: Colors.amber[50],
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your skin impact score has increased',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your ${_proAlert!.type} score went from '
                        '${_proAlert!.fromScore} to ${_proAlert!.toScore} '
                        "between your last two assessments, moving from "
                        "'${_proAlert!.fromBand}' to '${_proAlert!.toBand}'. "
                        'This is a pattern worth discussing with your dermatologist '
                        'at your next visit. This app tracks patterns; it does not diagnose or prescribe.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _handleShareWithDoctor(context);
                            },
                            child: const Text('Share with my doctor'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _proAlertDismissed = true;
                              });
                              _dismissalService.recordDismissal('proTrajectory');
                            },
                            child: const Text('Dismiss for now'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            if (_pendingFlareCandidate != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Possible flare detected',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Your skin seems to have been particularly rough the last couple of days. Would you call this a flare?',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _handleFlareCandidateResponse(
                              _pendingFlareCandidate!,
                              FlareCandidateResponse.yes,
                            ),
                            child: const Text('Yes'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () => _handleFlareCandidateResponse(
                              _pendingFlareCandidate!,
                              FlareCandidateResponse.notReally,
                            ),
                            child: const Text('Not really'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _handleFlareCandidateResponse(
                              _pendingFlareCandidate!,
                              FlareCandidateResponse.remindMeLater,
                            ),
                            child: const Text('Remind me later'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ═══════════════════════════════════════════════════════════
            // SECTION 3: RED FLAGS (EMERGENCY ALERTS)
            // ═══════════════════════════════════════════════════════════

            if (redFlags.isNotEmpty) ...[
              const Text(
                '🚨 Health Alerts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...redFlags.map((flag) {
                final body = StringBuffer(flag.whyImportant);
                if (flag.guidelineSource != null) {
                  body.write('\n\nSource: ${flag.guidelineSource}');
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ClinicalNoteWidget(
                    type: ClinicalNoteType.redFlag,
                    title: flag.symptom,
                    body: body.toString(),
                    actionLabel: 'Learn more',
                    onAction: () => showWhenToSeeDoctorModal(context),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.xl),
            ],

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Having a flare right now?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _logPatientInitiatedFlare,
                      icon: const Icon(Icons.report),
                      label: const Text('Log a flare'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 3: DASHBOARD TITLE
            // ═══════════════════════════════════════════════════════════

            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 4: TODAY'S RISK SCORE + SECTION 6: WEEKLY STATS
            // (On tablet/desktop: side-by-side; on phone: stacked)
            // ═══════════════════════════════════════════════════════════

            LayoutBuilder(
              builder: (context, _) {
                final isWide = Responsive.isTablet(context) ||
                    Responsive.isDesktop(context);
                final riskCard = todayRiskScore > 0
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Today\'s Risk Score',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        '$todayRiskScore / 100',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  RiskBadgeWidget(
                                    type: todayRiskScore <= 30
                                        ? RiskBadgeType.low
                                        : todayRiskScore <= 60
                                            ? RiskBadgeType.medium
                                            : RiskBadgeType.high,
                                    label: todayRiskScore <= 30
                                        ? 'Low Risk'
                                        : todayRiskScore <= 60
                                            ? 'Moderate'
                                            : 'High Risk',
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              LinearProgressIndicator(
                                value: todayRiskScore / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation(
                                  todayRiskScore <= 30
                                      ? Colors.green
                                      : todayRiskScore <= 60
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildRiskExplanation(todayRiskScore),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                logDensity.isLow
                                    ? 'Limited data this week — log daily for accurate insights.'
                                    : 'Based on ${logDensity.loggedDays}/${logDensity.windowDays} days logged this week.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.edit,
                                    size: 32, color: Colors.grey),
                                const SizedBox(height: AppSpacing.md),
                                const Text(
                                  'No log for today yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ElevatedButton(
                                  onPressed: () async {
                                    final currentUser =
                                        FirebaseAuth.instance.currentUser;
                                    if (currentUser == null) {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const LoginScreen(),
                                        ),
                                      );
                                      return;
                                    }
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DailyLogScreen(
                                          dailyLogService: _dailyLogService,
                                          firestoreService: _firestoreService,
                                          condition: selectedCondition,
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  child: const Text('Create Today\'s Log'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                final statsCard = logs.isNotEmpty
                    ? WeeklyStatsCard(analytics: analytics)
                    : const SizedBox.shrink();

                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final now = DateTime.now();
                final todayStr =
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                final recentLogs = analytics.getLogsFromLastDays(7);
                final itchByDate = {
                  for (final log in recentLogs)
                    '${log.date.year}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}':
                        log.itchIntensity,
                };

                final wearableWidget = WearableDashboardWidget(
                  uid: uid,
                  date: todayStr,
                  itchByDate: itchByDate,
                );

                final weeklyFocusCard = WeeklyFocusCard(
                  uid: FirebaseAuth.instance.currentUser?.uid ?? '',
                  condition: selectedCondition,
                  recentLogs: recent30DayLogs,
                  proAssessments: _proAssessments,
                );

                if (isWide && logs.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      riskCard,
                      const SizedBox(height: AppSpacing.xl),
                      weeklyFocusCard,
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: statsCard),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: wearableWidget),
                        ],
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    riskCard,
                    const SizedBox(height: AppSpacing.xl),
                    weeklyFocusCard,
                    const SizedBox(height: AppSpacing.xl),
                    if (logs.isNotEmpty) ...[
                      statsCard,
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    wearableWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 5: INSIGHTS BUTTON
            // ═══════════════════════════════════════════════════════════

            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💡 Clinical Insights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Get evidence-backed insights from your symptom patterns. See your triggers, clinical mechanisms, and peer-reviewed evidence.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InsightsScreen(
                                dailyLogService: _dailyLogService,
                                condition: selectedCondition,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics),
                        label: const Text('View Insights & Evidence'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 6: ENVIRONMENTAL DATA (Weekly stats now in SECTION 4)
            // ═══════════════════════════════════════════════════════════

            if (_isLoading)
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonLogCard(),
                  SizedBox(height: 12),
                  SkeletonLogCard(),
                  SizedBox(height: 12),
                  SkeletonStatsRow(),
                ],
              )
            else if (_errorMessage != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚠️ Error Loading Data',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _errorMessage!,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                      const SizedBox(height: AppSpacing.md),
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
              GridView.count(
                crossAxisCount: Responsive.gridColumns(context),
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                children: [
                  // Weather Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🌤️ Weather',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${(_envData!['weather']['main']['temp'] as num).toInt()}°C',
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
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                  // Location Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📍 Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Lat: ${_envData!['latitude']?.toStringAsFixed(4)}°',
                          ),
                          Text(
                            'Lon: ${_envData!['longitude']?.toStringAsFixed(4)}°',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),

            if (_envData != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _fetchEnvironmentalData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Data'),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 8: RECENT LOGS
            // ═══════════════════════════════════════════════════════════

            RecentLogsList(
              logs: analytics.getLogsFromLastDays(7),
              onStartCheckIn: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyLogScreen(
                      dailyLogService: _dailyLogService,
                      firestoreService: _firestoreService,
                      condition: selectedCondition,
                    ),
                  ),
                );
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 9: DAILY LOG BUTTON
            // ═══════════════════════════════════════════════════════════

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
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
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Track your symptoms daily to identify triggers and patterns',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final currentUser =
                              FirebaseAuth.instance.currentUser;
                          if (currentUser == null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                            return;
                          }
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DailyLogScreen(
                                dailyLogService: _dailyLogService,
                                firestoreService: _firestoreService,
                                condition: selectedCondition,
                              ),
                            ),
                          );
                          setState(() {});
                        },
                        child: const Text('Start Daily Check-In'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ═══════════════════════════════════════════════════════════
            // SECTION 10: REPORT GENERATION
            // ═══════════════════════════════════════════════════════════

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate Health Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Create ABDM-compliant PDF reports to share with healthcare providers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportsScreen(
                                firestoreService: _firestoreService,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Generate Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildRiskExplanation(int riskScore) {
    String explanation;
    Color color;

    if (riskScore <= 30) {
      explanation = '✓ Low risk - Continue current management strategy';
      color = Colors.green;
    } else if (riskScore <= 60) {
      explanation =
          '~ Moderate risk - Monitor triggers closely and ensure adherence';
      color = Colors.orange;
    } else {
      explanation =
          '⚠️ High risk - Intensify preventive measures and contact dermatologist';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        explanation,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

}
