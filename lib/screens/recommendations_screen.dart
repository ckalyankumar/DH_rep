import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dhealth/models/recommendation_model.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/widgets/clinical_note_widget.dart'
    show ClinicalNoteType, ClinicalNoteWidget, showWhenToSeeDoctorModal;
import 'package:dhealth/services/recommendation_service.dart';
import 'package:dhealth/services/recommendation_export_service.dart';
import 'package:dhealth/services/personalization_service.dart';
import 'package:dhealth/data/disorder_registry.dart';

class RecommendationsScreen extends StatefulWidget {
  final String selectedCondition;
  final VoidCallback? onBack;
  final dynamic dailyLogService;

  const RecommendationsScreen({
    super.key,
    required this.selectedCondition,
    this.onBack,
    this.dailyLogService,
  });

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen>
    with SingleTickerProviderStateMixin {
  int? expandedIndex;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: RecommendationService.showDoctorPrescribed ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Recommendation> _getRecommendations() {
    final base = RecommendationService.getAllRecommendations(widget.selectedCondition);
    final logs = _getLogs();
    return PersonalizationService.getPersonalizedRecommendations(
      widget.selectedCondition,
      base,
      logsDynamic: logs.isNotEmpty ? logs : null,
    );
  }

  List<dynamic> _getLogs() {
    try {
      if (widget.dailyLogService != null) {
        final logs = widget.dailyLogService.getLogs();
        if (logs is List) return logs;
      }
    } catch (_) {}
    return [];
  }

  List<Recommendation> _getSelfCareRecs() {
    final all = _getRecommendations();
    return all.where((r) => r.type == RecommendationType.selfCare).toList();
  }

  List<Recommendation> _getDoctorPrescribedRecs() {
    return RecommendationService.getDoctorPrescribedRecommendations(widget.selectedCondition);
  }

  void _exportCsv() {
    final recs = _getRecommendations();
    final csv = RecommendationExportService.toCsv(recs);
    Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${recs.length} recommendations to clipboard. Paste into Excel or a CSV file for dermatologist review.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final disorder = DisorderRegistry.getDisorder(widget.selectedCondition);
    final redFlags = disorder.redFlags;
    final guidelineSources =
        RecommendationService.getGuidelineSources(widget.selectedCondition);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        leading: widget.onBack != null
            ? IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export for dermatologist review',
            onPressed: _exportCsv,
          ),
        ],
        bottom: RecommendationService.showDoctorPrescribed
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Self-Care'),
                  Tab(text: 'Discuss with Doctor'),
                ],
              )
            : null,
      ),
      body: RecommendationService.showDoctorPrescribed
          ? _buildTabbedBody(redFlags, guidelineSources)
          : _buildSingleBody(redFlags, guidelineSources),
    );
  }

  Widget _buildTabbedBody(
    List<RedFlag> redFlags,
    List<GuidelineSource> guidelineSources,
  ) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTabContent(
          redFlags: redFlags,
          guidelineSources: guidelineSources,
          recommendations: _getSelfCareRecs(),
        ),
        _buildTabContent(
          redFlags: redFlags,
          guidelineSources: guidelineSources,
          recommendations: _getDoctorPrescribedRecs(),
        ),
      ],
    );
  }

  Widget _buildTabContent({
    required List<RedFlag> redFlags,
    required List<GuidelineSource> guidelineSources,
    required List<Recommendation> recommendations,
  }) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildDisclaimerBanner(),
        const SizedBox(height: 16),
        if (redFlags.isNotEmpty) ...[
          _buildRedFlagsSection(redFlags),
          const SizedBox(height: 16),
        ],
        _buildGuidelineSourcesSection(guidelineSources),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._buildRecommendationCards(recommendations),
              _buildConsultDermatologistCTA(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleBody(
    List<RedFlag> redFlags,
    List<GuidelineSource> guidelineSources,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDisclaimerBanner(),
          const SizedBox(height: 16),
          if (redFlags.isNotEmpty) ...[
            _buildRedFlagsSection(redFlags),
            const SizedBox(height: 16),
          ],
          _buildGuidelineSourcesSection(guidelineSources),
          const SizedBox(height: 16),
          _buildRecommendationsList(_getSelfCareRecs()),
          _buildConsultDermatologistCTA(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildRecommendationCards(List<Recommendation> recommendations) {
    return [
      Text(
        recommendations.isNotEmpty &&
                recommendations.first.type == RecommendationType.selfCare
            ? 'Self-Care (things you can try)'
            : 'Discuss with your dermatologist',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2c3e50),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        recommendations.isNotEmpty &&
                recommendations.first.type == RecommendationType.selfCare
            ? 'Evidence-based steps you can take. Always discuss changes with your care team.'
            : 'These options require a prescription or in-clinic visit.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
          height: 1.4,
        ),
      ),
      const SizedBox(height: 12),
      if (recommendations.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No recommendations in this category.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        )
      else
        ...List.generate(recommendations.length, (index) {
          final rec = recommendations[index];
          final isExpanded = expandedIndex == index;
          return _buildRecommendationCard(rec, index, isExpanded);
        }),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildRecommendationsList(List<Recommendation> recommendations) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildRecommendationCards(recommendations),
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'These recommendations are for informational purposes and are based on published guidelines. They are not a substitute for professional medical advice. Discuss any changes with your dermatologist or healthcare provider.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedFlagsSection(List<RedFlag> redFlags) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'When to Seek Urgent Care',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 12),
          ...redFlags.map((flag) {
            final body = StringBuffer(
              '${flag.whyImportant}\n\nAction: ${flag.actionToTake}',
            );
            if (flag.guidelineSource != null) {
              body.write('\n\nSource: ${flag.guidelineSource}');
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClinicalNoteWidget(
                type: ClinicalNoteType.redFlag,
                title: flag.symptom,
                body: body.toString(),
                actionLabel: 'Learn more',
                onAction: () => showWhenToSeeDoctorModal(context),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGuidelineSourcesSection(
    List<GuidelineSource> guidelineSources,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guideline & Council References',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 12),
          ...guidelineSources.map(
            (src) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    src.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2c3e50),
                    ),
                  ),
                  Text(
                    src.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  if (src.url != null)
                    GestureDetector(
                      onTap: () => _launchUrl(src.url!),
                      child: Text(
                        'Learn more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildRecommendationCard(
    Recommendation rec,
    int index,
    bool isExpanded,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: const Border(
            left: BorderSide(color: Color(0xFF3498db), width: 4),
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  expandedIndex = isExpanded ? null : index;
                });
              },
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
                            rec.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2c3e50),
                            ),
                          ),
                        ),
                        _buildPriorityBadge(rec.priority),
                      ],
                    ),
                    if (rec.source.isNotEmpty ||
                        (rec.gradeLevel != null &&
                            rec.gradeLevel!.isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(
                          [
                            if (rec.source.isNotEmpty) rec.source,
                            if (rec.gradeLevel != null &&
                                rec.gradeLevel!.isNotEmpty)
                              rec.gradeLevel!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      rec.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6c757d),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: rec.tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFf8f9fa),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6c757d),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Why This Matters', rec.rationale),
                    const SizedBox(height: 16),
                    _buildDetailSection('How to Implement', null),
                    ...rec.steps
                        .asMap()
                        .entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${e.key + 1}. ${e.value}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6c757d),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),
                    _buildDetailSection('Expected Benefits', rec.benefits),
                    const SizedBox(height: 16),
                    _buildDetailSection('Scientific Evidence', rec.evidence),
                    const SizedBox(height: 8),
                    Text(
                      'Source: ${rec.source}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6c757d),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              RecommendationService.markImplemented(rec);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Marked as implemented!'),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3498db),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Mark as Implemented'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              RecommendationService.markForLater(rec);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Saved for later'),
                                  ),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Save for Later'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String? content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2c3e50),
          ),
        ),
        if (content != null) ...[
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6c757d),
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriorityBadge(RecommendationPriority priority) {
    final String label = priority == RecommendationPriority.high
        ? 'HIGH'
        : priority == RecommendationPriority.medium
            ? 'MEDIUM'
            : 'LOW';
    Color bgColor;
    Color textColor;
    switch (priority) {
      case RecommendationPriority.high:
        bgColor = const Color(0x000fffee);
        textColor = const Color(0xFFe74c3c);
        break;
      case RecommendationPriority.medium:
        bgColor = const Color(0xFFfef6e6);
        textColor = const Color(0xFFf39c12);
        break;
      case RecommendationPriority.low:
        bgColor = const Color(0x000ffeef);
        textColor = const Color(0xFF27ae60);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildConsultDermatologistCTA() {
    const findDermUrl =
        'https://www.aad.org/public/find-a-dermatologist';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.health_and_safety, size: 32, color: Color(0xFF3498db)),
          const SizedBox(height: 12),
          const Text(
            'Discuss these recommendations with your dermatologist',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2c3e50),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _launchUrl(findDermUrl),
            child: const Text(
              'Find a dermatologist (AAD)',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF3498db),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
