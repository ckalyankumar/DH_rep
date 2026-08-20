import 'package:flutter/material.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/widgets/symptom_card_widget.dart';

class PredictionsScreen extends StatelessWidget {
  final String selectedCondition;
  final VoidCallback onBack;

  const PredictionsScreen({
    super.key,
    required this.selectedCondition,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final factors = _getFactorsForCondition(selectedCondition);
    final timeline = _getTimelineForCondition(selectedCondition);
    final riskForecast = _generateSevenDayForecast();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sample data banner — TODO: replace with dynamic data from PredictionService
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFFFE082), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sample data',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('backToDashboardButton'),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Flare Risk Analysis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            
            // Summary Cards — TODO: replace with dynamic data from PredictionService
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSummaryCard(context, title: 'Current Risk Level', value: '64%'),
                  _buildSummaryCard(context, title: 'Days Until Peak Risk', value: '3'),
                  _buildSummaryCard(context, title: 'Confidence Score', value: '87%'),
                ],
              ),
            ),

            // Contributing Risk Factors
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Contributing Risk Factors',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxWidth < 600
                          ? constraints.maxWidth * 0.65
                          : 320.0;
                      return SizedBox(
                        height: h,
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: factors
                              .map(
                                (factor) => SymptomCardWidget(
                                  title: factor['name'] as String,
                                  value: factor['value'] as String,
                                  borderColor: _getBorderColorForImpact(
                                    context,
                                    factor['impact'] as String,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 7-Day Risk Forecast Chart ✅ FIXED: Changed mainAxisAlignment from 'end' to 'spaceEvenly'
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '7-Day Risk Forecast',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildRiskChart(context, riskForecast),
                ],
              ),
            ),

            // Historical Timeline
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Historical Flare Timeline',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxWidth < 600
                          ? constraints.maxWidth * 0.65
                          : 320.0;
                      return SizedBox(
                        height: h,
                        child: _buildTimeline(context, timeline),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.surface,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 28,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskChart(BuildContext context, List<int> risks) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxRisk = risks.reduce((a, b) => a > b ? a : b);
    const barWidth = 32.0;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          days.length,
          (index) {
            final height = (risks[index] / maxRisk) * 150; // ✅ Reduced to 150 for comfort
            return SizedBox(
              width: barWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // ✅ FIXED: Changed from 'end' to 'spaceEvenly'
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible( // ✅ Wrap text in Flexible to allow shrinking
                    child: Text(
                      '${risks[index]}%',
                      style: textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: barWidth,
                    height: height.toDouble(),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible( // ✅ Wrap text in Flexible
                    child: Text(
                      days[index],
                      style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<Map<String, String>> items) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: colorScheme.secondary,
                  width: 4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['date'] ?? '',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  item['title'] ?? '',
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  item['description'] ?? '',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getBorderColorForImpact(BuildContext context, String impact) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (impact) {
      case 'high':
        return colorScheme.error;
      case 'medium':
        // TODO: no clear token for warning/medium
        return const Color(0xFFF39C12);
      case 'low':
        return colorScheme.primary;
      default:
        return colorScheme.secondary;
    }
  }

  // TODO: replace with dynamic data from PredictionService
  List<Map<String, dynamic>> _getFactorsForCondition(String condition) {
    if (condition == 'psoriasis') {
      return [
        {'name': 'Stress Level', 'value': 'High (7/10)', 'impact': 'high'},
        {'name': 'Weather', 'value': 'Cold & Dry', 'impact': 'high'},
        {'name': 'Medication Adherence', 'value': '85%', 'impact': 'medium'},
        {'name': 'Sleep Quality', 'value': 'Good (7.2hrs)', 'impact': 'low'},
        {'name': 'Alcohol Consumption', 'value': '2 drinks/week', 'impact': 'medium'},
        {'name': 'Sun Exposure', 'value': 'Low (15min/day)', 'impact': 'medium'},
      ];
    } else {
      return [
        {'name': 'Environmental Allergens', 'value': 'High (Pollen)', 'impact': 'high'},
        {'name': 'Skin Hydration', 'value': '72% (Low)', 'impact': 'high'},
        {'name': 'Scratch Episodes', 'value': '8/week', 'impact': 'high'},
        {'name': 'Sleep Disruption', 'value': '3 nights/week', 'impact': 'medium'},
        {'name': 'Diet factors', 'value': 'Dairy detected', 'impact': 'medium'}, // Language policy: associative only — no causal claims
        {'name': 'Exercise Frequency', 'value': '4 days/week', 'impact': 'low'},
      ];
    }
  }

  // TODO: replace with dynamic data from PredictionService
  List<int> _generateSevenDayForecast() {
    return [52, 58, 64, 68, 62, 55, 50];
  }

  // TODO: replace with dynamic data from PredictionService
  List<Map<String, String>> _getTimelineForCondition(String condition) {
    if (condition == 'psoriasis') {
      return [
        {
          'date': 'Nov 18, 2025',
          'title': 'Moderate Flare',
          'description': 'PASI score: 12.4 - Observed alongside stress at work', // Language policy: associative only — no causal claims
        },
        {
          'date': 'Oct 3, 2025',
          'title': 'Mild Flare',
          'description': 'PASI score: 8.2 - Weather change'
        },
        {
          'date': 'Aug 15, 2025',
          'title': 'Treatment Adjustment',
          'description': 'Dosage increased, good response'
        },
        {
          'date': 'Jul 2, 2025',
          'title': 'Remission Period',
          'description': 'PASI score: 3.1 - Excellent control'
        },
      ];
    } else {
      return [
        {
          'date': 'Nov 20, 2025',
          'title': 'Moderate Flare',
          'description': 'SCORAD: 38 - Associated with high pollen count', // Language policy: associative only — no causal claims
        },
        {
          'date': 'Oct 12, 2025',
          'title': 'Mild Itch Episode',
          'description': 'SCORAD: 22 - Observed alongside stress', // Language policy: associative only — no causal claims
        },
        {
          'date': 'Sep 5, 2025',
          'title': 'Good Control Period',
          'description': 'SCORAD: 15 - Consistent treatment'
        },
        {
          'date': 'Aug 18, 2025',
          'title': 'Dietary association identified',
          'description': 'Dairy correlation detected'
        },
      ];
    }
  }
}
