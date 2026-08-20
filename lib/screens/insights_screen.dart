import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/daily_log_service.dart';
import 'package:dhealth/data/psoriasis_clinical_data.dart';
import 'package:dhealth/data/eczema_clinical_data.dart';
import 'package:dhealth/widgets/clinical_note_widget.dart'
    show ClinicalNoteType, ClinicalNoteWidget, showWhenToSeeDoctorModal;
import 'package:dhealth/widgets/empty_state_widget.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// INSIGHTS SCREEN - CLINICAL EVIDENCE DISPLAY
///
/// Displays evidence-backed insights with:
/// - Clinical mechanism explanations
/// - Peer-reviewed paper citations (clickable links)
/// - Flare risk predictions
/// - Red flag emergency warnings
/// - Streak motivation tracking
/// ═══════════════════════════════════════════════════════════════════════

class InsightsScreen extends StatefulWidget {
  final DailyLogService dailyLogService;
  final String condition;

  const InsightsScreen({
    super.key,
    required this.dailyLogService,
    required this.condition,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  DailyInsightSummary? _insights;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);
    try {
      final logs = widget.dailyLogService.getLogs();

      if (logs.isEmpty) {
        setState(() {
          _errorMessage =
              'Create at least 10 daily logs to generate insights';
          _isLoading = false;
        });
        return;
      }

      // Get disorder based on condition
      final disorder = widget.condition.toLowerCase() == 'psoriasis'
          ? PsoriasisDisorder()
          : EczemaDisorder();

      final insights = await InsightEngine.generateDailyInsights(
        logs,
        widget.condition,
        disorder, // ADD THIS REQUIRED PARAMETER
      );

      setState(() {
        _insights = insights;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading insights: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💡 Clinical Insights & Evidence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
            tooltip: 'Refresh insights',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _insights == null
                  ? const Center(child: Text('No insights available'))
                  : _buildInsightsView(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInsights,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clinical Disclaimer (Always show first)
          _buildClinicalDisclaimerBanner(),
          const SizedBox(height: 20),

          // Health Score Card
          _buildHealthScoreCard(),
          const SizedBox(height: 20),

          // Flare Risk Prediction
          _buildFlareRiskCard(),
          const SizedBox(height: 20),

          // Red Flags Section (if any - PRIORITY)
          if (_insights!.redFlags.isNotEmpty) ...[
            _buildRedFlagsSection(),
            const SizedBox(height: 24),
          ],

          // Detected Triggers with Evidence
          if (_insights!.detectedTriggers.isNotEmpty) ...[
            _buildTriggersSection(),
            const SizedBox(height: 24),
          ] else ...[
            const EmptyStateWidget(
              emoji: '🔍',
              title: 'Not enough data yet',
              description:
                  'Log at least 8 weeks of daily entries to see your personal trigger patterns.',
            ),
            const SizedBox(height: 24),
          ],

          // Patterns Section
          if (_insights!.patterns.isNotEmpty) ...[
            _buildPatternsSection(),
            const SizedBox(height: 24),
          ],

          // Streak Motivation
          _buildStreakSection(),
          const SizedBox(height: 24),

          // Data Quality Disclaimer
          _buildDataQualityBanner(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildClinicalDisclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _insights!.disclaimer,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard() {
    final score = _insights!.healthScore;
    final label = _insights!.healthLabel;
    final color = _getHealthColor(score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overall Health Score',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.2),
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score/100',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Status: $label',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on ${_insights!.dataPoints} daily logs · ${_insights!.analysisConfidence} confidence · '
              '${_insights!.loggedDaysLast7}/${_insights!.logWindowDays} days logged this week',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlareRiskCard() {
    final risk = _insights!.flareRiskPrediction;

    return Card(
      color: _getRiskColor(risk.riskPercentage).withValues(alpha:0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📊 7-Day Flare Risk',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  risk.riskLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _getRiskColor(risk.riskPercentage),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: risk.riskPercentage / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getRiskColor(risk.riskPercentage),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${risk.riskPercentage.toStringAsFixed(1)}% risk',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (risk.topTriggers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Top triggers: ${risk.topTriggers.join(", ")}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Confidence: ${risk.confidenceLevel}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedFlagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚨 Red Flags - Seek Medical Attention',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red),
        ),
        const SizedBox(height: 12),
        ..._insights!.redFlags.map((flag) {
          final body = StringBuffer('Why: ${flag.whyImportant}\n\nAction: ${flag.actionToTake}');
          if (flag.guidelineSource != null) {
            body.write('\n\nSource: ${flag.guidelineSource}');
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClinicalNoteWidget(
              type: ClinicalNoteType.redFlag,
              title: '${flag.urgency.toUpperCase()}: ${flag.symptom}',
              body: body.toString(),
              actionLabel: 'Learn more',
              onAction: () => showWhenToSeeDoctorModal(context),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTriggersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Primary Triggers',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Based on statistical analysis of your symptom patterns',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ..._insights!.detectedTriggers.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final trigger = entry.value;
          return _buildTriggerCard(index, trigger);
        }),
        const SizedBox(height: 16),
        const ClinicalNoteWidget(
          type: ClinicalNoteType.info,
          title: 'Statistical association only',
          body:
              'These patterns are derived from your personal data using Spearman rank '
              'correlation. They indicate associations, not causes, and are not a medical diagnosis.',
        ),
      ],
    );
  }

  Widget _buildTriggerCard(int index, EvidencedTrigger trigger) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trigger.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${trigger.confidence.toStringAsFixed(0)}% confidence',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Mechanism'),
                Text(
                  trigger.mechanism,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Prevention Strategy'),
                Text(
                  trigger.preventionStrategy,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Expected Improvement'),
                Text(
                  '${trigger.expectedImprovement.toStringAsFixed(0)}% reduction in symptoms',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                if (trigger.lagDays > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Note: Peak effect typically occurs ${trigger.lagDays} days after exposure reduction',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
                if (trigger.evidence.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('Evidence'),
                  ..._buildEvidenceList(trigger.evidence),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Identified Patterns',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ..._insights!.patterns.map((pattern) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pattern.pattern,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${(pattern.confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.blue[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pattern.description,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Occurred ${pattern.occurrences} times • ',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Predictability: ${pattern.predictability}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStreakSection() {
    final streak = _insights!.streakInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔥 Your Progress',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStreakStat('Current Streak', '${streak.currentStreak}', 'days'),
                    _buildStreakStat('Best Streak', '${streak.bestStreak}', 'days'),
                    _buildStreakStat('Good Days', '${streak.goodDays.length}', 'total'),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: streak.motivationScore / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Motivation: ${streak.motivationLabel}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataQualityBanner() {
    final lowDensity = _insights!.loggedDaysLast7 < 3;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lowDensity
                  ? 'Limited data this week — insights are based on '
                      '${_insights!.loggedDaysLast7}/${_insights!.logWindowDays} days logged. '
                      'Logging more days will make patterns and risk scores more accurate.'
                  : 'Analysis based on ${_insights!.dataPoints} logs with ${_insights!.analysisConfidence} confidence, '
                      'including ${_insights!.loggedDaysLast7}/${_insights!.logWindowDays} days logged this week.',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  List<Widget> _buildEvidenceList(List<ClinicalEvidence> evidence) {
    return evidence.map((ev) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => _launchURL(ev.url),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ev.authors} (${ev.year})',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  ev.keyFinding,
                  style: const TextStyle(fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '📖 ${ev.journal}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const Spacer(),
                    Text(
                      'Citations: ${ev.citationCount}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStreakStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        Text(
          unit,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COLOR HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Color _getHealthColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _getRiskColor(double risk) {
    if (risk >= 70) return Colors.red;
    if (risk >= 40) return Colors.orange;
    return Colors.green;
  }

  Future<void> _launchURL(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open URL: $e')),
        );
      }
    }
  }
}
