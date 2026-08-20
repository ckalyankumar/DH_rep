import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/services/firestore_daily_log_service.dart';
import 'package:dhealth/services/firestore_reports_service.dart';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/user_report.dart';
import 'package:dhealth/screens/share_with_doctor_screen.dart';

// =============================================================================
// ReportsScreen — StatefulWidget
// =============================================================================

class ReportsScreen extends StatefulWidget {
  final FirestoreDailyLogService? firestoreService;

  const ReportsScreen({
    super.key,
    this.firestoreService,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

// =============================================================================
// State — init, data fetching, build
// =============================================================================

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<DailyLog>> _logsFuture;
  String _selectedPeriod = '30days'; // 7days, 30days, 90days, all

  User? _currentUser;
  bool _authChecked = false;
  StreamSubscription<User?>? _authSubscription;

  FirestoreDailyLogService? get _effectiveLogService {
    if (widget.firestoreService != null) return widget.firestoreService;
    if (_currentUser != null) {
      return FirestoreDailyLogService(userId: _currentUser!.uid);
    }
    return null;
  }

  FirestoreReportsService? get _effectiveReportsService {
    if (_currentUser != null) {
      return FirestoreReportsService(userId: _currentUser!.uid);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _authChecked = true;

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _authChecked = true;
          _currentUser = user;
          _logsFuture = _fetchLogs(); // Refetch when auth changes (e.g. login)
        });
      }
    });

    _logsFuture = _fetchLogs();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  int get _daysForPeriod {
    switch (_selectedPeriod) {
      case '7days':
        return 7;
      case '30days':
        return 30;
      case '90days':
        return 90;
      case 'all':
      default:
        return 365;
    }
  }

  Future<List<DailyLog>> _fetchLogs() async {
    final service = _effectiveLogService;
    if (service == null) return [];
    try {
      return await service.getLogsForLastDays(_daysForPeriod);
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      return [];
    }
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _fetchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveLogService != null) {
      return _buildReportsScaffold();
    }
    if (widget.firestoreService == null && !_authChecked) {
      return _buildLoadingScaffold();
    }
    if (widget.firestoreService == null && _currentUser == null) {
      return _buildNoAuthScaffold();
    }
    return _buildNoFirestoreScaffold();
  }

  // --- Build — scaffolds and period selector ---

  Scaffold _buildLoadingScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Reports'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Scaffold _buildNoAuthScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Reports'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sign in to view your reports.\nYour data is stored at /users/{your id}/reports.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Scaffold _buildNoFirestoreScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Reports'),
      ),
      body: const Center(
        child: Text(
          'Reports require Firestore connection',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildReportsScaffold() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('📊 Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share with doctor',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ShareWithDoctorScreen(),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Trends'),
            Tab(text: 'Statistics'),
            Tab(text: 'Triggers'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: TabBarView(
              children: [
                _buildTrendsTab(),
                _buildStatisticsTab(),
                _buildTriggersTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _PeriodSelectorRow(
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPeriod = value;
                    _logsFuture = _fetchLogs();
                  });
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // Trends tab
  // =============================================================================

  Widget _buildTrendsTab() {
    return FutureBuilder<List<DailyLog>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildTrendsEmptyState();
        }

        final logs = [...snapshot.data!];
        logs.sort((a, b) => a.date.compareTo(b.date));
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        final last7DaysLogs =
            logs.where((l) => l.date.isAfter(sevenDaysAgo)).toList();
        final trendLogs =
            last7DaysLogs.isNotEmpty ? last7DaysLogs : logs;
        final spots = _trendSpots(trendLogs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  _buildSeverityTrendCard(trendLogs, spots),
              const SizedBox(height: 16),
              _buildRecentEntriesCard(logs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendsEmptyState() {
    return const Center(child: _TrendsEmptyContent());
  }

  List<FlSpot> _trendSpots(List<DailyLog> logs) {
    return logs
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            e.value.severityScore.toDouble(),
          ),
        )
        .toList();
  }

  Widget _buildSeverityTrendCard(List<DailyLog> logs, List<FlSpot> spots) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Severity Trend',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(_buildTrendLineChartData(logs, spots)),
            ),
            const SizedBox(height: 16),
            _buildTrendSummary(logs),
          ],
        ),
      ),
    );
  }

  LineChartData _buildTrendLineChartData(
    List<DailyLog> logs,
    List<FlSpot> spots,
  ) {
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) => _trendBottomTitle(value, logs),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt()}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.blue,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withValues(alpha:0.3),
          ),
        ),
      ],
    );
  }

  Widget _trendBottomTitle(double value, List<DailyLog> logs) {
    final index = value.toInt();
    if (index >= 0 && index < logs.length) {
      return Text(
        DateFormat('M/d').format(logs[index].date),
        style: const TextStyle(fontSize: 10),
      );
    }
    return const Text('');
  }

  Widget _buildRecentEntriesCard(List<DailyLog> logs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Entries',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildRecentEntriesList(logs),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // Statistics tab
  // =============================================================================

  Widget _buildStatisticsTab() {
    return FutureBuilder<List<DailyLog>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        final logs = snapshot.data!;
        final avg = _avgSeverity(logs);
        final max = _maxSeverity(logs);
        final min = _minSeverity(logs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                'Average Severity',
                '${avg.toStringAsFixed(1)}/100',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Highest Severity',
                '$max/100',
                Colors.red,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Lowest Severity',
                '$min/100',
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Total Entries',
                '${logs.length}',
                Colors.purple,
              ),
              const SizedBox(height: 16),
              _buildDistributionCard(logs),
              if (_effectiveReportsService != null) ...[
                const SizedBox(height: 16),
                _buildSavedReportsCard(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedReportsCard() {
    final reportsService = _effectiveReportsService!;
    return FutureBuilder<List<UserReport>>(
      future: reportsService.getReports(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.length : 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.folder_special, color: Colors.teal, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saved reports',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '$count from Firestore',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _avgSeverity(List<DailyLog> logs) {
    if (logs.isEmpty) return 0.0;
    final sum = logs.map((l) => l.severityScore).reduce((a, b) => a + b);
    return sum / logs.length;
  }

  int _maxSeverity(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    return logs.map((l) => l.severityScore).reduce((a, b) => a > b ? a : b);
  }

  int _minSeverity(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    return logs.map((l) => l.severityScore).reduce((a, b) => a < b ? a : b);
  }

  Widget _buildDistributionCard(List<DailyLog> logs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(sections: _buildDistributionSections(logs)),
              ),
            ),
            const SizedBox(height: 16),
            _buildDistributionLegend(),
          ],
        ),
      ),
    );
  }

  // =============================================================================
  // Triggers tab
  // =============================================================================

  Widget _buildTriggersTab() {
    return FutureBuilder<List<DailyLog>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        final logs = snapshot.data!;
        final triggerCounts = _countTriggers(logs);
        final sortedTriggers = triggerCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Most Common Triggers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (sortedTriggers.isEmpty)
                const Center(child: Text('No triggers recorded'))
              else
                ...sortedTriggers
                    .map(
                      (e) => _buildTriggerBar(
                        e.key,
                        e.value,
                        sortedTriggers.first.value,
                      ),
                    )
                    ,
              const SizedBox(height: 24),
              _buildTriggerSummaryCard(triggerCounts, sortedTriggers),
            ],
          ),
        );
      },
    );
  }

  Map<String, int> _countTriggers(List<DailyLog> logs) {
    final counts = <String, int>{};
    for (final log in logs) {
      if (log.triggers != null) {
        for (final trigger in log.triggers!) {
          counts[trigger] = (counts[trigger] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  Widget _buildTriggerSummaryCard(
    Map<String, int> triggerCounts,
    List<MapEntry<String, int>> sortedTriggers,
  ) {
    final mostCommon = _mostCommonTriggerKey(sortedTriggers);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _TriggerSummaryContent(
          totalUniqueTriggers: triggerCounts.length,
          mostCommon: mostCommon,
        ),
      ),
    );
  }

  String _mostCommonTriggerKey(List<MapEntry<String, int>> sortedTriggers) {
    return sortedTriggers.isNotEmpty ? sortedTriggers.first.key : 'N/A';
  }

  String _triggerDisplayLabel(String trigger) {
    return trigger.isNotEmpty
        ? trigger[0].toUpperCase() + trigger.substring(1)
        : trigger;
  }

  // =============================================================================
  // Shared UI — stat cards, distribution, legend
  // =============================================================================

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _StatCardRow(title: title, value: value, color: color),
      ),
    );
  }

  List<PieChartSectionData> _buildDistributionSections(List<DailyLog> logs) {
    const lowThreshold = 33;
    const highThreshold = 66;

    final lowCount =
        logs.where((l) => l.severityScore <= lowThreshold).length.toDouble();
    final mediumCount = logs
        .where((l) {
          final s = l.severityScore;
          return s > lowThreshold && s <= highThreshold;
        })
        .length
        .toDouble();
    final highCount =
        logs.where((l) => l.severityScore > highThreshold).length.toDouble();

    return [
      PieChartSectionData(
        value: lowCount,
        title: '${lowCount.toInt()}',
        color: Colors.green,
        radius: 50,
      ),
      PieChartSectionData(
        value: mediumCount,
        title: '${mediumCount.toInt()}',
        color: Colors.orange,
        radius: 50,
      ),
      PieChartSectionData(
        value: highCount,
        title: '${highCount.toInt()}',
        color: Colors.red,
        radius: 50,
      ),
    ];
  }

  Widget _buildDistributionLegend() {
    return const Column(
      children: [
        _LegendItem(label: 'Low (0-33)', color: Colors.green),
        SizedBox(height: 8),
        _LegendItem(label: 'Medium (34-66)', color: Colors.orange),
        SizedBox(height: 8),
        _LegendItem(label: 'High (67-100)', color: Colors.red),
      ],
    );
  }

  // --- Trend summary, recent entries, trigger bar helpers ---

  Widget _buildTrendSummary(List<DailyLog> logs) {
    if (logs.isEmpty) return const Text('No data');
    final recent = logs.last.severityScore;
    final previous = _previousSeverity(logs, recent);
    final trend = recent - previous;
    return _TrendSummaryRow(
      recent: recent,
      trend: trend,
      trendLabel: _trendLabel(trend),
      trendColor: _trendColor(trend),
    );
  }

  int _previousSeverity(List<DailyLog> logs, int recent) {
    return logs.length > 1 ? logs[logs.length - 2].severityScore : recent;
  }

  String _trendLabel(int trend) {
    if (trend > 0) return '↑ Worsening';
    if (trend < 0) return '↓ Improving';
    return '→ Stable';
  }

  Color _trendColor(int trend) {
    if (trend > 0) return Colors.red;
    if (trend < 0) return Colors.green;
    return Colors.grey;
  }

  List<Widget> _buildRecentEntriesList(List<DailyLog> logs) {
    return logs.reversed.take(5).map(_buildRecentEntryItem).toList();
  }

  Widget _buildRecentEntryItem(DailyLog log) {
    final severityColor = _getSeverityColor(log.severityScore);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _RecentEntryRow(log: log, severityColor: severityColor),
    );
  }

  Widget _buildTriggerBar(String trigger, int count, int maxCount) {
    final label = _triggerDisplayLabel(trigger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _TriggerBarContent(
        label: label,
        count: count,
        maxCount: maxCount,
      ),
    );
  }

  // --- Severity color (for badges / distribution) ---

  Color _getSeverityColor(int severity) {
    if (severity <= 33) return Colors.green;
    if (severity <= 66) return Colors.orange;
    return Colors.red;
  }
}

// =============================================================================
// Private helper widgets (extracted for readability)
// =============================================================================

class _PeriodSelectorRow extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String?> onPeriodChanged;

  const _PeriodSelectorRow({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Time Period:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        DropdownButton<String>(
          value: selectedPeriod,
          items: const [
            DropdownMenuItem(value: '7days', child: Text('7 Days')),
            DropdownMenuItem(value: '30days', child: Text('30 Days')),
            DropdownMenuItem(value: '90days', child: Text('90 Days')),
            DropdownMenuItem(value: 'all', child: Text('All Time')),
          ],
          onChanged: onPeriodChanged,
        ),
      ],
    );
  }
}

class _TrendsEmptyContent extends StatelessWidget {
  const _TrendsEmptyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.info, size: 48, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'No data available',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Start logging symptoms to see trends',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _StatCardRow extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCardRow({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(Icons.bar_chart, color: color, size: 32),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendSummaryRow extends StatelessWidget {
  final int recent;
  final int trend;
  final String trendLabel;
  final Color trendColor;

  const _TrendSummaryRow({
    required this.recent,
    required this.trend,
    required this.trendLabel,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Trend',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              trendLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: trendColor,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Latest Score',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '$recent/100',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentEntryRow extends StatelessWidget {
  final DailyLog log;
  final Color severityColor;

  const _RecentEntryRow({
    required this.log,
    required this.severityColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM d, yyyy').format(log.date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              log.condition,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: severityColor.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${log.severityScore}/100',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: severityColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _TriggerBarContent extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;

  const _TriggerBarContent({
    required this.label,
    required this.count,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (count / maxCount * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$count times ($percentage%)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: count / maxCount,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(
              Colors.blue.withValues(alpha:0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _TriggerSummaryContent extends StatelessWidget {
  final int totalUniqueTriggers;
  final String mostCommon;

  const _TriggerSummaryContent({
    required this.totalUniqueTriggers,
    required this.mostCommon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trigger Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Total unique triggers: $totalUniqueTriggers',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Most common: $mostCommon',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
