import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dhealth/widgets/skeleton_widgets.dart';
import 'package:intl/intl.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/medication_profile.dart';
import 'package:dhealth/models/flare_event.dart';
import 'package:dhealth/models/medication_exception_event.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/utils/file_download_helper.dart';
import 'package:dhealth/services/clinical_messaging_service.dart';
import 'package:dhealth/services/doctor_portal_data_service.dart';
import 'package:dhealth/services/report_generator_service.dart';
import 'package:dhealth/services/fhir_bundle_generator.dart';
import 'package:dhealth/screens/doctor_clinical_thread_screen.dart';
import 'package:dhealth/debug_agent_log.dart';

/// Read-only view of a linked patient's logs with ABDM report download.
///
/// Doctor can view logs and download PDF or FHIR bundle.
/// No mutations to patient data.
class DoctorPatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String? patientDisplayName;
  final String doctorEmail;
  final DateTime? accessGrantedAt;

  const DoctorPatientDetailScreen({
    super.key,
    required this.patientId,
    this.patientDisplayName,
    required this.doctorEmail,
    this.accessGrantedAt,
  });

  @override
  State<DoctorPatientDetailScreen> createState() =>
      _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  final DoctorPortalDataService _dataService = DoctorPortalDataService();
  final ClinicalMessagingService _messagingService = ClinicalMessagingService();
  List<DailyLog> _logs = [];
  List<WeeklySelfEfficacyPulse> _pulses = [];
  List<ProAssessment> _proAssessments = [];
  List<TriggerProCorrelation> _triggerProCorrelations = [];
  MedicationProfile? _medicationProfile;
  List<MedicationExceptionEvent> _medicationExceptions = [];
  List<FlareEvent> _flareEvents = [];
  Map<String, dynamic>? _profileDoc;
  String? _patientAbhaId;
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = '30days';

  int get _days {
    switch (_selectedPeriod) {
      case '7days':
        return 7;
      case '90days':
        return 90;
      case 'all':
        return 365;
      default:
        return 30;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profileDoc =
          await _dataService.getPatientProfile(patientId: widget.patientId);
      final logs = await _dataService.getPatientLogs(
        patientId: widget.patientId,
        days: _days,
      );
      final pulses = await _dataService.getPatientPulses(
        patientId: widget.patientId,
        weeks: 12,
      );
      final pros = await _dataService.getPatientProAssessments(
        patientId: widget.patientId,
        days: _days,
      );
      final medicationProfile =
          await _dataService.getPatientMedicationProfile(
        patientId: widget.patientId,
      );
      final medicationExceptions =
          await _dataService.getPatientMedicationExceptions(
        patientId: widget.patientId,
        days: _days,
      );
      final flareEvents = await _dataService.getPatientFlareEvents(
        patientId: widget.patientId,
        days: _days,
      );
      final correlations = TriggerProCorrelationEngine.correlate(
        logs,
        pros,
      );
      // #region agent log
      agentDebugLog(
        location: 'doctor_patient_detail_screen.dart:_loadLogs',
        message: 'load patient data success',
        hypothesisId: 'H2',
        data: {
          'days': _days,
          'logCount': logs.length,
          'pulseCount': pulses.length,
          'proCount': pros.length,
        },
      );
      // #endregion
      setState(() {
        _logs = logs;
        _pulses = pulses;
        _proAssessments = pros;
        _triggerProCorrelations = correlations;
        _medicationProfile = medicationProfile;
        _medicationExceptions = medicationExceptions;
        _flareEvents = flareEvents;
        _profileDoc = profileDoc;
        _patientAbhaId = _readPatientAbhaId(profileDoc);
        _isLoading = false;
      });
      _recordDoctorView('logs');
    } catch (e) {
      // #region agent log
      agentDebugLog(
        location: 'doctor_patient_detail_screen.dart:_loadLogs',
        message: 'load patient data failed',
        hypothesisId: 'H2',
        data: {
          'errorType': e.runtimeType.toString(),
          'errorBrief': e.toString().length > 160 ? e.toString().substring(0, 160) : e.toString(),
        },
      );
      // #endregion
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _displayName =>
      widget.patientDisplayName ??
      (_logs.isNotEmpty
          ? DoctorPortalDataService.defaultPatientName(_logs.first.condition)
          : DoctorPortalDataService.defaultPatientName(null));

  String get _condition =>
      _logs.isNotEmpty ? _logs.first.condition : 'Unknown';

  Future<void> _downloadPdf() async {
    if (_logs.isEmpty) {
      _showSnackBar('No patient data available for this report.');
      return;
    }

    _showSnackBar('Generating PDF...');
    try {
      final sortedLogs = List<DailyLog>.from(_logs)
        ..sort((a, b) => a.date.compareTo(b.date));
      final startDate = sortedLogs.first.date;
      final endDate = sortedLogs.last.date;

      DateTime? patientDob;
      String? patientAbhaId;
      try {
        final profile = _profileDoc?['profile'];
        if (profile is Map<String, dynamic>) {
          final dobRaw = profile['dateOfBirth'];
          if (dobRaw is String && dobRaw.isNotEmpty) {
            try {
              patientDob = DateFormat('yyyy-MM-dd').parse(dobRaw);
            } catch (_) {
              patientDob = null;
            }
          }
          patientAbhaId = (profile['abhaId'] as String?)?.trim();
        }
      } catch (_) {
        patientDob = null;
        patientAbhaId = null;
      }

      final doc = await ReportGeneratorService.generateHealthReport(
        patientName: _displayName,
        condition: _condition,
        logs: sortedLogs,
        startDate: startDate,
        endDate: endDate,
        medicationProfile: _medicationProfile,
        medicationExceptions:
            _medicationExceptions.isNotEmpty ? _medicationExceptions : null,
        flareEvents: _flareEvents.isNotEmpty ? _flareEvents : null,
        weeklyPulses: _pulses.isNotEmpty ? _pulses : null,
        proAssessments: _proAssessments.isNotEmpty ? _proAssessments : null,
        triggerProCorrelations:
            _triggerProCorrelations.isNotEmpty ? _triggerProCorrelations : null,
        weeklyFocuses: null,
        patientDateOfBirth: patientDob,
        patientAbhaId: patientAbhaId,
      );

      final bytes = await doc.save();
      final filename = 'dhealth_report_${widget.patientId}.pdf';
      final path = await saveBytesToFile(bytes, filename, mimeType: 'application/pdf');
      _showSnackBar(path.startsWith('downloaded:') ? 'PDF downloaded' : 'PDF saved to $path');
      _recordDoctorView('report');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _downloadFhir() async {
    if (_logs.isEmpty) {
      _showSnackBar('No patient data available for this export.');
      return;
    }

    _showSnackBar('Generating FHIR bundle...');
    try {
      final sortedLogs = List<DailyLog>.from(_logs)
        ..sort((a, b) => a.date.compareTo(b.date));

      final bundle = FHIRBundleGenerator.generateFHIRBundle(
        patientId: widget.patientId,
        patientName: _displayName,
        condition: _condition,
        logs: sortedLogs,
        reportDate: DateTime.now(),
        medicationExceptions:
            _medicationExceptions.isNotEmpty ? _medicationExceptions : null,
        flareEvents: _flareEvents.isNotEmpty ? _flareEvents : null,
      );

      final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);
      final bytes = utf8.encode(jsonStr);
      final filename = 'dhealth_fhir_${widget.patientId}.json';
      final path = await saveBytesToFile(bytes, filename, mimeType: 'application/json');
      _showSnackBar(path.startsWith('downloaded:') ? 'FHIR bundle downloaded' : 'FHIR bundle saved to $path');
      _recordDoctorView('report');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _recordDoctorView(String dataScope) async {
    try {
      await _messagingService.recordDoctorView(
        patientId: widget.patientId,
        doctorEmail: widget.doctorEmail,
        dataScope: dataScope,
      );
    } catch (_) {
      // Best-effort; do not block UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadLogs,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonLogCard(),
            SizedBox(height: 12),
            SkeletonLogCard(),
            SizedBox(height: 12),
            SkeletonStatsRow(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPatientHeaderSection(),
          const SizedBox(height: 12),
          _buildRangeSelectorSection(),
          const SizedBox(height: 12),
          _buildRiskTrajectorySection(),
          const SizedBox(height: 12),
          _buildProHistorySection(),
          const SizedBox(height: 12),
          _buildTriggerCorrelationSection(),
          const SizedBox(height: 12),
          _buildSelfEfficacySection(),
          const SizedBox(height: 12),
          _buildReportDownloadsSection(),
          const SizedBox(height: 12),
          _buildClinicalMessagesSection(),
          const SizedBox(height: 12),
          _buildReadOnlyFooter(),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeaderSection() {
    final conditionLabel = _conditionLabel(_condition);
    final lastActive = _latestActivityDate();
    final lastActiveText = lastActive == null
        ? 'Last active: —'
        : 'Last active: ${DateFormat('MMM d, yyyy').format(lastActive)}';
    final abhaText =
        (_patientAbhaId == null || _patientAbhaId!.isEmpty) ? null : _patientAbhaId;

    final accessGrantedAt = widget.accessGrantedAt;
    final accessText = accessGrantedAt == null
        ? 'Access granted · Patient can revoke at any time'
        : 'Access granted ${DateFormat('MMM d, yyyy').format(accessGrantedAt)} · Patient can revoke at any time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _tealChip(conditionLabel),
                              Text(
                                lastActiveText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (abhaText != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'ABHA ID: $abhaText',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
          ),
          child: Text(
            accessText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.teal.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSelectorSection() {
    return _sectionCard(
      title: 'Time range',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _periodChoice('7d', value: '7days'),
          _periodChoice('30d', value: '30days'),
          _periodChoice('90d', value: '90days'),
          _periodChoice('All', value: 'all'),
        ],
      ),
    );
  }

  Widget _periodChoice(String label, {required String value}) {
    final selected = _selectedPeriod == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) {
        if (selected) return;
        setState(() {
          _selectedPeriod = value;
        });
        _loadLogs();
      },
    );
  }

  Widget _buildRiskTrajectorySection() {
    final series = _dailyRiskSeries();
    if (series.isEmpty) {
      return _sectionCard(
        title: 'Risk score over time',
        subtitle: 'No data available for this time range.',
        child: Text(
          'No patient data available for this time range.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final flareDays = _flareDaySet();
    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i].score.toDouble()));
    }

    return _sectionCard(
      title: 'Risk score over time',
      subtitle: 'Daily risk score from patient-entered data.',
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 25,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (series.length / 4).clamp(1, 30).toDouble(),
                  getTitlesWidget: (v, meta) {
                    final idx = v.round();
                    if (idx < 0 || idx >= series.length) return const SizedBox.shrink();
                    final d = series[idx].day;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('MMM d').format(d),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                color: Colors.teal.shade700,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, barData) {
                    final idx = spot.x.round();
                    if (idx < 0 || idx >= series.length) return false;
                    return flareDays.contains(_dayStart(series[idx].day));
                  },
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4.5,
                      color: Colors.red.shade700,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.teal.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProHistorySection() {
    final chosen = _proHistoryInstrument();
    final type = chosen.$1;
    final list = chosen.$2;

    if (list.isEmpty) {
      return _sectionCard(
        title: 'PRO history',
        subtitle: 'No PRO questionnaires available for this time range.',
        child: Text(
          'No patient questionnaire data available.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final title = type == ProAssessmentType.dlqi ? 'DLQI history' : 'POEM history';

    return _sectionCard(
      title: title,
      subtitle: 'Date · Score · Severity · Trend',
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++)
            _proRow(
              current: list[i],
              previous: i + 1 < list.length ? list[i + 1] : null,
            ),
        ],
      ),
    );
  }

  Widget _proRow({required ProAssessment current, ProAssessment? previous}) {
    final dateText = DateFormat('MMM d, yyyy').format(current.date);
    final scoreText = current.totalScore.toString();
    final bandText = current.severityBand;

    String trend = '→';
    bool mcid = false;
    if (previous != null) {
      final change = current.totalScore - previous.totalScore;
      if (change > 0) trend = '↑';
      if (change < 0) trend = '↓';
      mcid = _crossedMcid(previous, current);
    }

    final bg = mcid ? Colors.teal.withValues(alpha: 0.08) : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(dateText, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              scoreText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              bandText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: Text(
              trend,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerCorrelationSection() {
    if (_triggerProCorrelations.isEmpty) {
      return _sectionCard(
        title: 'Trigger–PRO correlation',
        subtitle: 'No correlations available (insufficient data).',
        child: Text(
          'Not enough longitudinal data to compute correlations.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return _sectionCard(
      title: 'Trigger–PRO correlation',
      subtitle: 'Statistical association from patient personal data.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.8),
                ),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Text('ρ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Text('Weeks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(flex: 5, child: Text('Avg PRO (high vs low)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          for (final c in _triggerProCorrelations.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 4, child: Text(_prettyCategory(c.category), style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 2, child: Text(c.r.toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Expanded(flex: 2, child: Text('${c.weeks}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                  Expanded(
                    flex: 5,
                    child: Text(
                      '${c.avgProHigh.toStringAsFixed(1)} vs ${c.avgProLow.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            "Statistical association from patient's personal data. Not a diagnosis.",
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfEfficacySection() {
    if (_pulses.isEmpty) {
      return _sectionCard(
        title: 'Self-efficacy pulse',
        subtitle: 'No weekly confidence data available.',
        child: Text(
          'No patient confidence data available.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final sorted = List<WeeklySelfEfficacyPulse>.from(_pulses)
      ..sort((a, b) => a.weekStartDate.compareTo(b.weekStartDate));

    final spots = <FlSpot>[];
    for (var i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].score.toDouble()));
    }

    return _sectionCard(
      title: 'Self-efficacy pulse',
      subtitle: 'Weekly confidence score',
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 10,
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: 2,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                color: Colors.teal.shade700,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.teal.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportDownloadsSection() {
    return _sectionCard(
      title: 'Report downloads',
      subtitle: 'Reports reflect the selected date range above.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _downloadPdf,
            icon: const Text('⬇'),
            label: const Text('Download PDF Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _downloadFhir,
            icon: const Text('⬇'),
            label: const Text('Download FHIR Bundle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalMessagesSection() {
    return _sectionCard(
      title: 'Clinical messages',
      subtitle: 'View the message thread with this patient.',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.chat_bubble_outline),
        title: const Text('Open thread'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DoctorClinicalThreadScreen(
              patientId: widget.patientId,
              patientDisplayName: _displayName,
              doctorEmail: widget.doctorEmail,
              logs: _logs,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyFooter() {
    return Text(
      'Read-only. This data belongs to your patient.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  Set<DateTime> _flareDaySet() {
    final days = <DateTime>{};
    for (final e in _flareEvents) {
      days.add(_dayStart(e.onsetDate));
    }
    return days;
  }

  DateTime? _latestActivityDate() {
    DateTime? latest;
    for (final l in _logs) {
      if (latest == null || l.date.isAfter(latest)) latest = l.date;
    }
    for (final p in _proAssessments) {
      if (latest == null || p.date.isAfter(latest)) latest = p.date;
    }
    return latest;
  }

  List<_DailyRiskPoint> _dailyRiskSeries() {
    if (_logs.isEmpty) return const [];
    final byDay = <DateTime, int>{};
    for (final l in _logs) {
      final d = _dayStart(l.date);
      final score = l.calculateRiskScore();
      final existing = byDay[d];
      if (existing == null || score > existing) {
        byDay[d] = score;
      }
    }
    final days = byDay.keys.toList()..sort((a, b) => a.compareTo(b));
    return [
      for (final d in days) _DailyRiskPoint(day: d, score: byDay[d] ?? 0),
    ];
  }

  (String, List<ProAssessment>) _proHistoryInstrument() {
    final dlqi = _proAssessments
        .where((a) => a.type == ProAssessmentType.dlqi)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (dlqi.isNotEmpty) return (ProAssessmentType.dlqi, dlqi);
    final poem = _proAssessments
        .where((a) => a.type == ProAssessmentType.poem)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return (ProAssessmentType.poem, poem);
  }

  bool _crossedMcid(ProAssessment prev, ProAssessment curr) {
    final delta = (curr.totalScore - prev.totalScore).abs().toDouble();
    if (curr.type == ProAssessmentType.dlqi) {
      return delta >= DlqiValidation.dlqiMcid;
    }
    return delta >= PoemValidation.poemMcid;
  }

  static String _prettyCategory(String raw) {
    final v = raw.replaceAll('.', ' ').replaceAll('_', ' ').trim();
    if (v.isEmpty) return raw;
    return v[0].toUpperCase() + v.substring(1);
  }

  static String _conditionLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('psoriasis')) return 'Psoriasis';
    if (v.contains('eczema') || v.contains('atopic')) return 'Eczema';
    if (v == 'psoriasis') return 'Psoriasis';
    if (v == 'eczema') return 'Eczema';
    return 'Unknown';
  }

  static Widget _tealChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.teal.shade800,
        ),
      ),
    );
  }

  static String? _readPatientAbhaId(Map<String, dynamic>? doc) {
    final profile = doc?['profile'];
    if (profile is! Map) return null;
    final v = (profile['abhaId'] as String?)?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }
}

class _DailyRiskPoint {
  final DateTime day;
  final int score;

  const _DailyRiskPoint({required this.day, required this.score});
}
