import 'package:flutter/material.dart';
import 'package:dhealth/services/daily_log_service.dart';

/// Widget to show deduplication statistics
class DeduplicationStatsWidget extends StatelessWidget {
  final DailyLogService dailyLogService;

  const DeduplicationStatsWidget({
    super.key,
    required this.dailyLogService,
  });

  @override
  Widget build(BuildContext context) {
    final stats = dailyLogService.getDeduplicationStats();
    final totalLogs = stats['totalLogs'] as int;
    final uniqueDays = stats['uniqueDays'] as int;
    final logsRemoved = stats['logsRemoved'] as int;
    final reductionPercentage = stats['reductionPercentage'] as String;

    if (totalLogs == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      color: logsRemoved > 0 ? Colors.orange[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  logsRemoved > 0 ? Icons.info : Icons.check_circle,
                  color: logsRemoved > 0 ? Colors.orange : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  logsRemoved > 0 ? 'Duplicates Removed' : 'All Unique',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: logsRemoved > 0 ? Colors.orange[900] : Colors.green[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$uniqueDays unique days (${stats['message']})',
              style: const TextStyle(fontSize: 11),
            ),
            if (logsRemoved > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Reduction: $reductionPercentage% ($logsRemoved entries)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[800],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to show detailed removal information
class DuplicateDetailsDialog extends StatelessWidget {
  final DailyLogService dailyLogService;

  const DuplicateDetailsDialog({
    super.key,
    required this.dailyLogService,
  });

  @override
  Widget build(BuildContext context) {
    final removalDetails = dailyLogService.getRemovalDetails();

    if (removalDetails.isEmpty) {
      return AlertDialog(
        title: const Text('Duplicate Details'),
        content: const Text('No duplicates found. All logs are unique (1 per day).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Duplicate Entries Removed'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: removalDetails.map((detail) {
              final date = detail['date'] as String;
              final kept = detail['kept'] as Map;
              final removed = detail['removed'] as List;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 6),
                              const Text(
                                'KEPT (Highest Risk)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Time: ${kept['time']} | Risk: ${kept['riskScore']} | Mood: ${kept['mood']}/5 | Itch: ${kept['itch']}/10',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...removed.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final rem = entry.value as Map;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[200]!),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.remove_circle,
                                      size: 14, color: Colors.red[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'REMOVED #$index',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Time: ${rem['time']} | Risk: ${rem['riskScore']} | Mood: ${rem['mood']}/5 | Itch: ${rem['itch']}/10',
                                style: const TextStyle(fontSize: 8),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Show duplicate details dialog
void showDuplicateDetailsDialog(BuildContext context, DailyLogService dailyLogService) {
  showDialog(
    context: context,
    builder: (context) => DuplicateDetailsDialog(dailyLogService: dailyLogService),
  );
}
