import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/screens/wearables/connect_devices_screen.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/widgets/empty_state_widget.dart';
import 'package:dhealth/widgets/skeleton_widgets.dart';

/// Self-contained wearable dashboard. Receives [uid] and [date] (yyyy-MM-dd).
/// Optional [itchByDate] for week grid itch dots (date -> itch 0-10).
class WearableDashboardWidget extends StatelessWidget {
  final String uid;
  final String date;
  final Map<String, int>? itchByDate;
  final WearableRepository? repository;
  final VoidCallback? onNavigateToConnect;

  const WearableDashboardWidget({
    super.key,
    required this.uid,
    required this.date,
    this.itchByDate,
    this.repository,
    this.onNavigateToConnect,
  });

  static String _providerName(WearableProvider p) {
    switch (p) {
      case WearableProvider.fitbit:
        return 'Fitbit';
      case WearableProvider.appleHealth:
        return 'Apple Health';
      case WearableProvider.garmin:
        return 'Garmin';
      case WearableProvider.oura:
        return 'Oura';
      case WearableProvider.samsungHealth:
        return 'Samsung Health';
      case WearableProvider.googleFit:
        return 'Google Fit';
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<_WearableData> _loadData() async {
    final repo = repository ?? WearableRepository();
    final sources = await repo.listActiveSources(uid);
    if (sources.isEmpty) {
      return _WearableData(hasConnection: false);
    }
    final today = await repo.getAggregate(uid, date);
    final week = await repo.getAggregates(uid, days: 7);
    return _WearableData(
      hasConnection: true,
      todayAggregate: today,
      weekAggregates: week,
    );
  }

  void _navigateToConnect(BuildContext context) {
    if (onNavigateToConnect != null) {
      onNavigateToConnect!();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ConnectDevicesScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<_WearableData>(
      future: _loadData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _SkeletonDashboard();
        }
        final data = snapshot.data;
        if (data == null || !data.hasConnection) {
          return EmptyStateWidget(
            emoji: '⌚',
            title: 'Connect a wearable',
            description:
                'Link Fitbit, Oura, Garmin or Apple Health to see passive health data.',
            actionLabel: 'Connect Device',
            onAction: () => _navigateToConnect(context),
          );
        }
        return _WearableDashboardContent(
          data: data,
          itchByDate: itchByDate ?? const {},
          providerName: _providerName,
          formatDate: _formatDate,
        );
      },
    );
  }
}

class _WearableData {
  final bool hasConnection;
  final DailyWearableAggregate? todayAggregate;
  final List<DailyWearableAggregate> weekAggregates;

  _WearableData({
    required this.hasConnection,
    this.todayAggregate,
    this.weekAggregates = const [],
  });
}

class _WearableDashboardContent extends StatelessWidget {
  final _WearableData data;
  final Map<String, int> itchByDate;
  final String Function(WearableProvider) providerName;
  final String Function(DateTime) formatDate;

  const _WearableDashboardContent({
    required this.data,
    required this.itchByDate,
    required this.providerName,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final agg = data.todayAggregate;
    final week = data.weekAggregates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (agg != null) ...[
          _TopStrip(aggregate: agg, providerName: providerName),
          SizedBox(height: AppSpacing.xl),
          _GaugesRow(aggregate: agg, weekAggregates: week),
          SizedBox(height: AppSpacing.xl),
        ],
        _WeekGrid(
          weekAggregates: week,
          itchByDate: itchByDate,
          formatDate: formatDate,
        ),
      ],
    );
  }
}

class _TopStrip extends StatelessWidget {
  final DailyWearableAggregate aggregate;
  final String Function(WearableProvider) providerName;

  const _TopStrip({
    required this.aggregate,
    required this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    final agg = aggregate;
    final minsSinceSync = DateTime.now().difference(agg.syncedAt).inMinutes;
    final syncLabel = minsSinceSync < 60 ? '$minsSinceSync min ago' : '${minsSinceSync ~/ 60}h ago';

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Wearable Snapshot",
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            '${providerName(agg.provider)} · synced $syncLabel',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _MetricCell(
                label: 'HRV',
                value: agg.hrvNightly != null ? '${agg.hrvNightly!.toInt()}' : '—',
                unit: 'ms',
                values: agg.hrvNightly != null ? [agg.hrvNightly!] : null,
              )),
              Expanded(child: _MetricCell(
                label: 'Sleep',
                value: agg.totalSleepMinutes != null ? (agg.totalSleepMinutes! / 60).toStringAsFixed(1) : '—',
                unit: 'h',
                values: agg.totalSleepMinutes != null ? [agg.totalSleepMinutes!.toDouble() / 60] : null,
              )),
              Expanded(child: _MetricCell(
                label: 'Steps',
                value: agg.steps != null ? '${agg.steps}' : '—',
                unit: '',
                values: agg.steps != null ? [agg.steps!.toDouble()] : null,
              )),
              Expanded(child: _MetricCell(
                label: 'Resting HR',
                value: agg.restingHeartRate != null ? '${agg.restingHeartRate}' : '—',
                unit: 'bpm',
                values: agg.restingHeartRate != null ? [agg.restingHeartRate!.toDouble()] : null,
              )),
            ],
          ),
          Divider(color: Colors.white.withValues(alpha: 0.4), height: AppSpacing.lg),
          Text(
            'Risk score includes wearable data',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final List<double>? values;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
    this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value + (unit.isNotEmpty ? ' $unit' : ''),
              style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        if (values != null && values!.isNotEmpty)
          SizedBox(
            height: 16,
            child: _MiniSparkline(values: values!, color: Colors.white.withValues(alpha: 0.7)),
          ),
      ],
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _MiniSparkline({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final pts = values.length < 2 ? [values.first, values.first] : values;
    final min = pts.reduce((a, b) => a < b ? a : b);
    final max = pts.reduce((a, b) => a > b ? a : b);
    final range = (max - min).clamp(1.0, double.infinity);
    final w = 40.0;
    final h = 14.0;
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = w * (i / (pts.length - 1));
      final y = h - (pts[i] - min) / range * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return CustomPaint(
      size: Size(w, h),
      painter: _SparklinePainter(path: path, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Path path;
  final Color color;

  _SparklinePainter({required this.path, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GaugesRow extends StatelessWidget {
  final DailyWearableAggregate aggregate;
  final List<DailyWearableAggregate> weekAggregates;

  const _GaugesRow({
    required this.aggregate,
    required this.weekAggregates,
  });

  @override
  Widget build(BuildContext context) {
    final sleepVal = (aggregate.totalSleepMinutes ?? 0) / 480 * 100;
    final sleepPct = (sleepVal.clamp(0.0, 100.0)).toInt();
    final hrvVal = aggregate.hrvNightly ?? 0;
    final hrvAvg = _hrvAvg(weekAggregates);
    final stepsVal = (aggregate.steps ?? 0) / 10000 * 100;
    final activityPct = (stepsVal.clamp(0.0, 100.0)).toInt();

    return Row(
      children: [
        Expanded(
          child: _GaugeCard(
            label: 'Sleep Quality',
            value: sleepPct,
            max: 100,
            color: AppTheme.sleep,
            subtitle: '${(aggregate.totalSleepMinutes ?? 0) ~/ 60}h · ${(aggregate.deepSleepPercent ?? 0).toStringAsFixed(0)}% deep · ${aggregate.awakenings ?? 0} awakenings',
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _GaugeCard(
            label: 'HRV Readiness',
            value: hrvVal.toInt(),
            max: 150,
            color: AppTheme.hrvPurple,
            subtitle: hrvAvg != null
                ? '${hrvVal >= hrvAvg ? "Above" : "Below"} your 7-day avg of ${hrvAvg.toStringAsFixed(0)}ms'
                : '${hrvVal.toStringAsFixed(0)} ms',
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: _GaugeCard(
            label: 'Activity',
            value: activityPct,
            max: 100,
            color: AppTheme.terracotta,
            subtitle: '${aggregate.steps ?? 0} steps · ${aggregate.activeMinutes ?? 0} active min',
          ),
        ),
      ],
    );
  }

  double? _hrvAvg(List<DailyWearableAggregate> list) {
    final withHrv = list.where((a) => a.hrvNightly != null).toList();
    if (withHrv.isEmpty) return null;
    return withHrv.map((a) => a.hrvNightly!).reduce((a, b) => a + b) / withHrv.length;
  }
}

class _GaugeCard extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final String subtitle;

  const _GaugeCard({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            SizedBox(height: AppSpacing.sm),
            Text(
              value.toString(),
              style: GoogleFonts.fraunces(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppTheme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final List<DailyWearableAggregate> weekAggregates;
  final Map<String, int> itchByDate;
  final String Function(DateTime) formatDate;

  const _WeekGrid({
    required this.weekAggregates,
    required this.itchByDate,
    required this.formatDate,
  });

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final aggByDate = {for (final a in weekAggregates) a.date: a};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Week', style: Theme.of(context).textTheme.labelMedium),
        SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 100,
          child: Row(
            children: days.map((d) {
              final dateStr = formatDate(d);
              final agg = aggByDate[dateStr];
              final sleepMins = agg?.totalSleepMinutes ?? 0;
              final sleepHrs = sleepMins / 60;
              final quality = _sleepQuality(agg);
              final itch = itchByDate[dateStr];
              final dayLabel = _dayLabels[d.weekday - 1];
              const barMaxHrs = 10.0;
              final barH = sleepMins > 0 ? (sleepHrs / barMaxHrs).clamp(0.0, 1.0) * 36 : 0.0;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Column(
                    children: [
                      Text(dayLabel, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      SizedBox(height: AppSpacing.xs),
                      if (barH > 0)
                        Container(
                          height: barH,
                          margin: EdgeInsets.only(bottom: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: quality == 'low' ? AppTheme.riskHigh
                                : quality == 'ok' ? AppTheme.riskMed
                                : AppTheme.riskLow,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      Text(
                        sleepMins > 0 ? '${sleepHrs.toStringAsFixed(1)}h' : '—',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                      if (itch != null) ...[
                        SizedBox(height: AppSpacing.xs),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: itch <= 3 ? AppTheme.riskLow
                                : itch <= 6 ? AppTheme.riskMed
                                : AppTheme.riskHigh,
                          ),
                        ),
                        Text('itch', style: TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  String _sleepQuality(DailyWearableAggregate? agg) {
    if (agg == null || agg.totalSleepMinutes == null) return 'ok';
    final hrs = agg.totalSleepMinutes! / 60;
    final score = agg.sleepScore;
    if (score != null) {
      if (score < 50) return 'low';
      if (score >= 70) return 'good';
      return 'ok';
    }
    if (hrs < 5) return 'low';
    if (hrs >= 7 && (agg.awakenings ?? 0) <= 2) return 'good';
    return 'ok';
  }
}

class _SkeletonDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(
          width: double.infinity,
          height: 120,
          borderRadius: AppSpacing.sm,
        ),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: SkeletonBox(width: double.infinity, height: 100, borderRadius: AppSpacing.sm)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(width: double.infinity, height: 100, borderRadius: AppSpacing.sm)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(width: double.infinity, height: 100, borderRadius: AppSpacing.sm)),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(width: 100, height: 14),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(width: double.infinity, height: 80, borderRadius: AppSpacing.sm),
      ],
    );
  }
}
