import 'package:flutter/material.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';

class RecentLogsList extends StatelessWidget {
  final List<DailyLog> logs;
  final VoidCallback? onStartCheckIn;

  const RecentLogsList({
    super.key,
    required this.logs,
    this.onStartCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Card(
        child: EmptyStateWidget(
          emoji: '📅',
          title: 'No logs yet',
          description:
              'Start your first daily check-in to track your skin health.',
          actionLabel: onStartCheckIn != null ? 'Start Check-In' : null,
          onAction: onStartCheckIn,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Logs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 7 ? 7 : logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final riskScore = log.calculateRiskScore();
                final dateStr = DateFormat('MMM d, yyyy').format(log.date);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '😐 ${log.mood}/5 | 🔥 ${log.itchIntensity}/10 | 😴 ${log.sleepQuality}/5',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _getRiskColor(riskScore).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Risk: $riskScore',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getRiskColor(riskScore),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(int score) {
    if (score <= 30) return AppTheme.riskLow;
    if (score <= 60) return AppTheme.riskMed;
    return AppTheme.riskHigh;
  }
}
