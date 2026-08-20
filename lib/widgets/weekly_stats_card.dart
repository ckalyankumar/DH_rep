import 'package:flutter/material.dart';
import 'package:dhealth/models/log_analytics.dart';
import 'package:dhealth/models/log_density_confidence.dart';

class WeeklyStatsCard extends StatelessWidget {
  final LogAnalytics analytics;

  const WeeklyStatsCard({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final avgRisk = analytics.getAverageRiskScore(7);
    final avgMood = analytics.getAverageMood(7);
    final avgItch = analytics.getAverageItch(7);
    final isImproving = analytics.isTrendImproving();
    final density = LogDensityConfidence.forLast7Days(analytics.logs);

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
                  'Last 7 Days',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isImproving ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isImproving ? 'Improving' : 'Worsening',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isImproving ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              density.loggedDays >= 5
                  ? '${density.loggedDays}/${density.windowDays} days this week — on track for accurate insights.'
                  : '${density.loggedDays}/${density.windowDays} days this week — '
                      '${(density.level == "medium" ? 0 : 3 - density.loggedDays).clamp(0, density.windowDays)} '
                      'more days would unlock medium confidence.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatTile(
                  'Avg Risk',
                  avgRisk.toStringAsFixed(0),
                  Colors.red,
                ),
                _buildStatTile(
                  'Avg Mood',
                  '${(avgMood / 5 * 10).toStringAsFixed(0)}%',
                  Colors.blue,
                ),
                _buildStatTile(
                  'Avg Itch',
                  '${(avgItch / 10 * 100).toStringAsFixed(0)}%',
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
