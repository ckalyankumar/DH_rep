import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/daily_wearable_aggregate.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/weekly_focus.dart';
import 'package:dhealth/models/medication_profile.dart';
import 'package:dhealth/models/flare_event.dart';
import 'package:dhealth/models/medication_exception_event.dart';
import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/services/report_generator_service_models.dart';

class ReportGeneratorService {
  /// Generate ABDM-compliant PDF report
  static Future<pw.Document> generateHealthReport({
    required String patientName,
    required String condition,
    required List<DailyLog> logs,
    required DateTime startDate,
    required DateTime endDate,
    MedicationProfile? medicationProfile,
    List<MedicationExceptionEvent>? medicationExceptions,
    List<FlareEvent>? flareEvents,
    List<WeeklySelfEfficacyPulse>? weeklyPulses,
    List<ProAssessment>? proAssessments,
    List<TriggerProCorrelation>? triggerProCorrelations,
    List<WeeklyFocus>? weeklyFocuses,
    List<DailyWearableAggregate>? aggregates,
    List<TriggerProCorrelation>? wearableCorrelations,
    List<WearableSource>? wearableSources,
    DateTime? patientDateOfBirth,
    String? patientAbhaId,
  }) async {
    final pdf = pw.Document();

    // #region agent log
    try {
      final logFile = File('debug-4d8c79.log');
      final logEntry = <String, dynamic>{
        'sessionId': '4d8c79',
        'runId': 'pre-fix',
        'hypothesisId': 'REP-A',
        'location': 'report_generator_service.dart:generateHealthReport',
        'message': 'generateHealthReport_started',
        'data': {
          'patientName': patientName,
          'condition': condition,
          'logCount': logs.length,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      logFile.writeAsStringSync(
        '${jsonEncode(logEntry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // #endregion

    // Calculate statistics
    final avgRisk = _calculateAverageRisk(logs);
    final avgMood = _calculateAverageMood(logs);
    final avgItch = _calculateAverageItch(logs);
    final maxRisk = _calculateMaxRisk(logs);
    final trend = _calculateTrend(logs);
    final loggingDensity = _calculateLoggingDensity(logs, startDate, endDate);

    // Derived metadata
    final generatedAt = DateTime.now();
    final reportId = _generateReportId(generatedAt);

    // #region agent log
    try {
      final logFile = File('debug-4d8c79.log');
      final logEntry = <String, dynamic>{
        'sessionId': '4d8c79',
        'runId': 'pre-fix',
        'hypothesisId': 'REP-B',
        'location': 'report_generator_service.dart:generateHealthReport',
        'message': 'report_id_generated',
        'data': {
          'reportId': reportId,
          'reportIdLength': reportId.length,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      logFile.writeAsStringSync(
        '${jsonEncode(logEntry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // #endregion

    final appVersion = await _getAppVersion();
    final redFlags = _computeRedFlagSummary(logs);
    final gaps = _computeDataGaps(logs, startDate, endDate);
    final adherence = _computeMedicationAdherencePatterns(
      medicationExceptions ?? const [],
      startDate,
      endDate,
    );
    final flares = _computeFlareSummary(
      flareEvents ?? const [],
      startDate,
      endDate,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) {
          if (context.pageNumber == 1) {
            // No visible header content on the first page.
            return pw.SizedBox.shrink();
          }
          return _buildHeader(patientName, reportId);
        },
        footer: (context) => _buildFooter(context, reportId),
        build: (context) {
          return [
            _buildIdentityBlock(generatedAt, reportId, appVersion),
            pw.SizedBox(height: 8),
            _buildPatientInfoBlock(
              patientName: patientName,
              condition: condition,
              medicationProfile: medicationProfile,
              startDate: startDate,
              endDate: endDate,
              loggingDensity: loggingDensity,
              patientDateOfBirth: patientDateOfBirth,
              patientAbhaId: patientAbhaId,
            ),
            pw.SizedBox(height: 8),
            if (medicationExceptions != null &&
                medicationExceptions.isNotEmpty)
              _buildMedicationAdherenceSection(adherence),
            if (medicationExceptions != null &&
                medicationExceptions.isNotEmpty)
              pw.SizedBox(height: 12),
            if (flareEvents != null && flareEvents.isNotEmpty)
              _buildFlareSection(flares),
            if (flareEvents != null && flareEvents.isNotEmpty)
              pw.SizedBox(height: 12),
            _buildDataProvenanceBlock(),
            pw.SizedBox(height: 16),
            _buildSummaryStatsBlock(
              avgRisk: avgRisk,
              avgMood: avgMood,
              avgItch: avgItch,
              maxRisk: maxRisk,
              trend: trend,
              loggingDensity: loggingDensity,
              gaps: gaps,
            ),
            pw.SizedBox(height: 16),
            _buildRedFlagSection(redFlags),
            pw.SizedBox(height: 16),
            if (weeklyPulses != null && weeklyPulses.isNotEmpty)
              _buildSelfEfficacySection(weeklyPulses),
            if (weeklyPulses != null && weeklyPulses.isNotEmpty)
              pw.SizedBox(height: 16),
            if (weeklyFocuses != null && weeklyFocuses.isNotEmpty)
              _buildWeeklyFocusSection(weeklyFocuses),
            if (weeklyFocuses != null && weeklyFocuses.isNotEmpty)
              pw.SizedBox(height: 16),
            if (proAssessments != null && proAssessments.isNotEmpty)
              _buildProSection(proAssessments, condition),
            if (proAssessments != null && proAssessments.isNotEmpty)
              pw.SizedBox(height: 16),
            if (triggerProCorrelations != null &&
                triggerProCorrelations.isNotEmpty)
              _buildTriggerProSection(triggerProCorrelations),
            if (triggerProCorrelations != null &&
                triggerProCorrelations.isNotEmpty)
              pw.SizedBox(height: 16),
            if (aggregates != null && aggregates.isNotEmpty)
              _buildWearableInsightsSection(
                aggregates,
                wearableCorrelations ??
                    (triggerProCorrelations
                            ?.where(
                                (c) => c.category.startsWith('wearable.'))
                            .toList() ??
                        []),
                '${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d, yyyy').format(endDate)}',
                wearableSources,
              ),
            if (aggregates != null && aggregates.isNotEmpty)
              pw.SizedBox(height: 16),
            if (logs.isNotEmpty) _buildLongitudinalSection(logs),
            if (logs.isNotEmpty) pw.SizedBox(height: 16),
            _buildMetadataUsagePrivacySection(generatedAt),
            pw.SizedBox(height: 16),
            _buildGovernanceBlock(),
          ];
        },
      ),
    );

    // #region agent log
    try {
      final logFile = File('debug-4d8c79.log');
      final logEntry = <String, dynamic>{
        'sessionId': '4d8c79',
        'runId': 'pre-fix',
        'hypothesisId': 'REP-C',
        'location': 'report_generator_service.dart:generateHealthReport',
        'message': 'generateHealthReport_completed',
        'data': {
          'redFlagCount': redFlags.events.length,
          'gapCount': gaps.significantGapCount,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      logFile.writeAsStringSync(
        '${jsonEncode(logEntry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // #endregion

    return pdf;
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  static String? _mostCommonProvider(
    List<DailyWearableAggregate> aggregates, {
    required bool hasSteps,
  }) {
    final withSteps = aggregates
        .where((a) => hasSteps ? a.steps != null : true)
        .map((a) => a.provider)
        .toList();
    if (withSteps.isEmpty) return null;
    final counts = <WearableProvider, int>{};
    for (final p in withSteps) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _providerDisplayName(top.key);
  }

  static String _providerDisplayName(WearableProvider p) {
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

  static String _formatDeviceConsent(
    List<DailyWearableAggregate> aggregates,
    List<WearableSource>? wearableSources,
  ) {
    if (wearableSources != null && wearableSources.isNotEmpty) {
      return wearableSources
          .where((s) => s.isActive)
          .map((s) {
            final scopes = s.scopes.map((sc) => sc.name).join(', ');
            final date = DateFormat('MMM d, yyyy').format(s.consentGrantedAt);
            return '${_providerDisplayName(s.provider)}: scopes $scopes, consent $date';
          })
          .join('\n');
    }
    final providers = aggregates.map((a) => a.provider).toSet();
    if (providers.isEmpty) return 'No connected devices.';
    return providers
        .map((p) => _providerDisplayName(p))
        .join(', ');
  }

  // Helper: Build stat box
  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      width: 95,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _formatCurrentTreatment(MedicationProfile? profile) {
    if (profile == null || profile.treatmentType == MedicationTreatmentType.none) {
      return 'No treatment recorded';
    }
    final base = profile.treatmentType.displayLabel;
    final name = profile.medicationName?.trim();
    if (name == null || name.isEmpty) {
      return base;
    }
    return '$base ($name)';
  }

  /// DLQI trend note: MCID-enforced (change >= 4 to label improving/worsening).
  static String? _dlqiTrendNote(List<ProAssessment> assessments) {
    final dlqis = assessments
        .where((a) => a.type == ProAssessmentType.dlqi)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (dlqis.length < 2) return null;
    final prev = dlqis[dlqis.length - 2].totalScore;
    final curr = dlqis.last.totalScore;
    final label = DlqiValidation.dlqiTrendLabel(prev, curr);
    if (label == 'stable') return null;
    if (label == 'improving') {
      return 'Note: DLQI improved by ${prev - curr} points (clinically meaningful per EADV consensus, PMID ${DlqiValidation.dlqiDevelopmentPmid}).';
    }
    return 'Note: DLQI increased by ${curr - prev} points (clinically meaningful worsening per EADV consensus, PMID ${DlqiValidation.dlqiDevelopmentPmid}).';
  }

  /// DLQI biologic eligibility: DLQI >= 10 per NICE TA and EADV S3 psoriasis guidelines.
  static String? _dlqiBiologicEligibilityNote(
    List<ProAssessment> assessments,
    String condition,
  ) {
    if (condition.toLowerCase() != 'psoriasis') return null;
    final dlqis = assessments
        .where((a) => a.type == ProAssessmentType.dlqi)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (dlqis.isEmpty) return null;
    final latestScore = dlqis.last.totalScore.toDouble();
    if (!DlqiValidation.isDlqiBiologicEligible(latestScore)) return null;
    return 'DLQI ≥10 meets the quality-of-life threshold for biologic eligibility consideration per NICE TA and EADV S3, typically alongside PASI/BSA criteria confirmed by a dermatologist.';
  }

  /// POEM trend note: MCID-enforced (change >= 3.4 to label improving/worsening).
  static String? _poemTrendNote(List<ProAssessment> assessments) {
    final poems = assessments
        .where((a) => a.type == ProAssessmentType.poem)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (poems.length < 2) return null;
    final prev = poems[poems.length - 2].totalScore;
    final curr = poems.last.totalScore;
    final label = PoemValidation.poemTrendLabel(prev, curr);
    if (label == 'stable') return null;
    if (label == 'improving') {
      return 'Note: POEM score improved by ${prev - curr} points (clinically meaningful per Schram et al. PMID ${PoemValidation.poemMcidPmid}).';
    }
    return 'Note: POEM score increased by ${curr - prev} points (clinically meaningful worsening per Schram et al. PMID ${PoemValidation.poemMcidPmid}).';
  }

  // Self-efficacy trend note for report
  static String _selfEfficacyTrendNote(List<WeeklySelfEfficacyPulse> pulses) {
    if (pulses.length < 3) return '';
    final first3 = pulses.take(3).map((p) => p.score).reduce((a, b) => a + b) / 3;
    final last3 = pulses.reversed.take(3).map((p) => p.score).reduce((a, b) => a + b) / 3;
    final diff = last3 - first3;
    if (diff <= -1.5) {
      return 'Note: Declining trend over recent weeks. Consider discussing adherence and support with patient.';
    }
    if (diff >= 1.5) {
      return 'Note: Improving trend in self-management confidence.';
    }
    return 'Note: Self-management confidence relatively stable.';
  }

  // Calculate average risk
  static double _calculateAverageRisk(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    final total = logs.fold<int>(0, (sum, log) => sum + log.calculateRiskScore());
    return total / logs.length;
  }

  // Calculate average mood
  static double _calculateAverageMood(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    final total = logs.fold<int>(0, (sum, log) => sum + log.mood);
    return total / logs.length;
  }

  // Calculate average itch
  static double _calculateAverageItch(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    final total = logs.fold<int>(0, (sum, log) => sum + log.itchIntensity);
    return total / logs.length;
  }

  // Calculate max risk
  static int _calculateMaxRisk(List<DailyLog> logs) {
    if (logs.isEmpty) return 0;
    return logs
        .map((log) => log.calculateRiskScore())
        .reduce((a, b) => a > b ? a : b);
  }

  // Calculate trend
  static bool _calculateTrend(List<DailyLog> logs) {
    if (logs.length < 2) return true;
    final firstHalf = (logs.length / 2).ceil();
    final first3Avg = logs
            .sublist(0, firstHalf)
            .fold<int>(0, (sum, log) => sum + log.calculateRiskScore()) /
        firstHalf;
    final last3Avg = logs
            .sublist(firstHalf)
            .fold<int>(0, (sum, log) => sum + log.calculateRiskScore()) /
        (logs.length - firstHalf);
    return last3Avg < first3Avg;
  }

  // Logging density for report period: distinct log days vs total days covered.
  static _LoggingDensity _calculateLoggingDensity(
    List<DailyLog> logs,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (logs.isEmpty) {
      final totalDays = endDate.difference(startDate).inDays + 1;
      return _LoggingDensity(
        loggedDays: 0,
        totalDays: totalDays > 0 ? totalDays : 0,
      );
    }

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = end.difference(start).inDays + 1;

    final distinctDays = <DateTime>{};
    for (final log in logs) {
      final d = DateTime(log.date.year, log.date.month, log.date.day);
      if (!d.isBefore(start) && !d.isAfter(end)) {
        distinctDays.add(d);
      }
    }
    return _LoggingDensity(
      loggedDays: distinctDays.length,
      totalDays: totalDays > 0 ? totalDays : 0,
    );
  }

  /// DLQI / POEM trajectory note when a band boundary is crossed with MCID-level worsening.
  static String? _proTrajectoryNote(List<ProAssessment> assessments) {
    if (assessments.isEmpty) return null;

    // Prefer DLQI when available, fall back to POEM.
    ProTrajectoryAlert? alert = ProTrajectoryAlert.detectTrajectory(
      assessments,
      type: ProAssessmentType.dlqi,
    );
    String instrumentLabel = 'DLQI';

    if (alert == null) {
      alert = ProTrajectoryAlert.detectTrajectory(
        assessments,
        type: ProAssessmentType.poem,
      );
      instrumentLabel = 'POEM';
    }

    if (alert == null || !alert.triggered) return null;

    return 'Quality-of-life trajectory: $instrumentLabel '
        '${alert.fromScore} → ${alert.toScore} '
        '(${alert.fromBand} → ${alert.toBand}). '
        'Trend represents a clinically meaningful worsening in the most recent assessments and '
        'is best interpreted alongside clinical examination.';
  }


  // ── Helpers for document identity, headers/footers, red flags, and gaps ──

  static String _generateReportId(DateTime now) {
    final rand = Random();
    final millis = now.millisecondsSinceEpoch;
    final rand32 = rand.nextInt(0xFFFFFFFF);
    // Combine into 128 bits via two 64-bit chunks.
    final hi = millis ^ rand32;
    final lo = (millis << 32) ^ rand32;
    String toHex64(int value) =>
        value.toUnsigned(64).toRadixString(16).padLeft(16, '0');
    final hex = (toHex64(hi) + toHex64(lo)).toLowerCase();
    // Format as 8-4-4-4-12.
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  static Future<String?> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildHeader(String patientName, String reportId) {
    final shortId = reportId.substring(0, 8);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              patientName,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
            pw.Text(
              '$shortId…',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, String reportId) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DHealth — For review by a licensed dermatologist only',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildIdentityBlock(
    DateTime generatedAt,
    String reportId,
    String? appVersion,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DHealth Health Summary Report',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(generatedAt)} IST',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Report ID: $reportId',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'ABDM Health Document Record',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Document type: HDR-SUMMARY',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (appVersion != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'DHealth app: $appVersion',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildPatientInfoBlock({
    required String patientName,
    required String condition,
    required MedicationProfile? medicationProfile,
    required DateTime startDate,
    required DateTime endDate,
    required _LoggingDensity loggingDensity,
    required DateTime? patientDateOfBirth,
    required String? patientAbhaId,
  }) {
    final dobDisplay = patientDateOfBirth != null
        ? DateFormat('d MMM yyyy').format(patientDateOfBirth)
        : 'Not provided';
    final abhaDisplay = (patientAbhaId != null &&
            patientAbhaId.trim().isNotEmpty)
        ? patientAbhaId.trim()
        : 'Not provided';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PATIENT INFORMATION',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Patient Name:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(patientName),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date of birth:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(dobDisplay),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ABHA ID:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(abhaDisplay),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Condition:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(condition.toUpperCase()),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Current treatment:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(_formatCurrentTreatment(medicationProfile)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Report Period:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${DateFormat('MMM d, yyyy').format(startDate)} - '
                    '${DateFormat('MMM d, yyyy').format(endDate)}',
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Entries:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('${loggingDensity.loggedDays} of ${loggingDensity.totalDays} days '
                      '(${loggingDensity.percentage.toStringAsFixed(0)}%)'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDataProvenanceBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DATA PROVENANCE',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Data source: All data is patient self-reported via the DHealth mobile application. '
            'No clinician-measured values are included.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Scoring methodology: Daily risk score: weighted composite score '
            '(DHealth Scoring Engine v1, condition-specific weights). Full methodology at dhealth.app/scoring.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Statistical methods: Trigger analysis uses Spearman rank correlation (ρ). '
            'Minimum 8 weeks of paired data required before correlations are shown. '
            'Associations do not imply causation.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'PRO instruments: POEM (Patient-Oriented Eczema Measure): validated 7-item self-report scale '
            '(Charman et al., 2004). DLQI (Dermatology Life Quality Index): validated 10-item self-report scale '
            '(Finlay & Khan, 1994).',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static _MedicationAdherencePatterns _computeMedicationAdherencePatterns(
    List<MedicationExceptionEvent> events,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    final inWindow = events.where((e) {
      final d = DateTime(e.logDate.year, e.logDate.month, e.logDate.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final missed = inWindow.where((e) => e.type == MedicationExceptionType.missedDose).toList();
    final stopped = inWindow.where((e) => e.type == MedicationExceptionType.stopped).toList();
    final changed = inWindow.where((e) => e.type == MedicationExceptionType.changedDose).toList();
    final sideEffects = inWindow.where((e) => e.type == MedicationExceptionType.sideEffect).toList();

    DateTime? lastExceptionAt;
    if (inWindow.isNotEmpty) lastExceptionAt = inWindow.last.occurredAt;

    int missedLast14 = 0;
    final cutoff14 = DateTime.now().subtract(const Duration(days: 14));
    for (final e in missed) {
      if (e.occurredAt.isAfter(cutoff14)) missedLast14++;
    }

    final recentNotes = <String>[];
    for (final e in sideEffects.reversed.take(3)) {
      final note = e.note?.trim();
      if (note != null && note.isNotEmpty) {
        recentNotes.add('${DateFormat('dd MMM').format(e.occurredAt)}: $note');
      }
    }

    return _MedicationAdherencePatterns(
      totalExceptions: inWindow.length,
      missedDoses: missed.length,
      missedDosesLast14Days: missedLast14,
      stoppedCount: stopped.length,
      changedDoseCount: changed.length,
      sideEffectCount: sideEffects.length,
      lastExceptionAt: lastExceptionAt,
      sideEffectNotes: recentNotes,
    );
  }

  static pw.Widget _buildMedicationAdherenceSection(
    _MedicationAdherencePatterns patterns,
  ) {
    final last =
        patterns.lastExceptionAt != null ? DateFormat('dd MMM yyyy').format(patterns.lastExceptionAt!) : '—';
    final nonAdherenceFlag = patterns.missedDosesLast14Days >= 3;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TREATMENT ADHERENCE (EXCEPTIONS)',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'This section records patient-noted exceptions to the planned schedule (missed doses, changes, stops, side effects). '
            'No interaction is treated as “unknown”, not “adherent”.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBox('Exceptions', '${patterns.totalExceptions}', PdfColors.blueGrey),
              _buildStatBox('Missed', '${patterns.missedDoses}', PdfColors.deepOrange),
              _buildStatBox('Last', last, PdfColors.teal),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            nonAdherenceFlag
                ? 'Pattern flag: ≥3 missed doses in the last 14 days (among recorded exceptions).'
                : 'Pattern flag: none.',
            style: pw.TextStyle(
              fontSize: 9,
              color: nonAdherenceFlag ? PdfColors.orange800 : PdfColors.grey700,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Dose changes: ${patterns.changedDoseCount} • Stops: ${patterns.stoppedCount} • Side effects: ${patterns.sideEffectCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          if (patterns.sideEffectNotes.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Recent side effects (free text):',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            ...patterns.sideEffectNotes.map(
              (t) => pw.Text(
                '- $t',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static _FlareSummary _computeFlareSummary(
    List<FlareEvent> events,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    final inWindow = events.where((e) {
      final d = DateTime(e.onsetDate.year, e.onsetDate.month, e.onsetDate.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.onsetDate.compareTo(b.onsetDate));

    final eligible = inWindow.where((e) => e.isOutcomeEligible).toList();

    DateTime? mostRecent;
    if (eligible.isNotEmpty) mostRecent = eligible.last.onsetDate;

    final resolvedDurations = <int>[];
    for (final e in eligible) {
      if (e.resolutionDate == null) continue;
      final days = DateTime(
            e.resolutionDate!.year,
            e.resolutionDate!.month,
            e.resolutionDate!.day,
          )
              .difference(DateTime(e.onsetDate.year, e.onsetDate.month, e.onsetDate.day))
              .inDays +
          1;
      if (days > 0) resolvedDurations.add(days);
    }

    double? avgDurationDays;
    if (resolvedDurations.isNotEmpty) {
      avgDurationDays =
          resolvedDurations.reduce((a, b) => a + b) / resolvedDurations.length;
    }

    final unconfirmed =
        inWindow.where((e) => e.source == FlareEventSource.algorithmUnconfirmed).length;

    return _FlareSummary(
      eligibleCount: eligible.length,
      unconfirmedCount: unconfirmed,
      mostRecentOnset: mostRecent,
      avgDurationDays: avgDurationDays,
    );
  }

  static pw.Widget _buildFlareSection(_FlareSummary summary) {
    final mostRecent = summary.mostRecentOnset != null
        ? DateFormat('dd MMM yyyy').format(summary.mostRecentOnset!)
        : '—';
    final dur = summary.avgDurationDays != null
        ? '${summary.avgDurationDays!.toStringAsFixed(1)} d'
        : '—';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'FLARE EVENTS',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Counts include patient-initiated and patient-confirmed events. Algorithm-unconfirmed events are shown separately and excluded from correlations.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatBox('Confirmed', '${summary.eligibleCount}', PdfColors.purple),
              _buildStatBox('Most recent', mostRecent, PdfColors.teal),
              _buildStatBox('Avg duration', dur, PdfColors.blueGrey),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Algorithm-unconfirmed (stored): ${summary.unconfirmedCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryStatsBlock({
    required double avgRisk,
    required double avgMood,
    required double avgItch,
    required int maxRisk,
    required bool trend,
    required _LoggingDensity loggingDensity,
    required DataGaps gaps,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SUMMARY STATISTICS',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBox('Avg Risk', avgRisk.toStringAsFixed(0), PdfColors.red),
            _buildStatBox(
                'Avg Mood',
                '${(avgMood / 5 * 10).toStringAsFixed(0)}%',
                PdfColors.blue),
            _buildStatBox(
                'Avg Itch',
                '${(avgItch / 10 * 100).toStringAsFixed(0)}%',
                PdfColors.orange),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBox('Max Risk', '$maxRisk', PdfColors.deepOrange),
            _buildStatBox(
                'Trend', trend ? 'Improving' : 'Worsening', trend ? PdfColors.green : PdfColors.orange),
            _buildStatBox(
              'Logging density',
              '${loggingDensity.loggedDays}/${loggingDensity.totalDays} days\n'
              '(${loggingDensity.percentage.toStringAsFixed(0)}%)',
              PdfColors.teal,
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          gaps.hasSignificantGaps
              ? 'Data gaps: ${gaps.significantGapCount} gap(s) of 7+ days detected. '
                'Longest gap: ${gaps.longestGapDays} days '
                '(${DateFormat('dd MMM yyyy').format(gaps.longestGapStart!)} – '
                '${DateFormat('dd MMM yyyy').format(gaps.longestGapEnd!)}).'
              : 'No significant data gaps detected.',
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSelfEfficacySection(
    List<WeeklySelfEfficacyPulse> weeklyPulses,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SELF-MANAGEMENT CONFIDENCE',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Weekly "How confident do you feel in managing your condition?" (0–10). '
          'A declining trend may indicate adherence risk or demoralization.',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Week of',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Score',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            ...weeklyPulses.take(12).map(
                  (p) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      DateFormat('MMM d, yyyy').format(p.weekStartDate),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      '${p.score}/10',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (weeklyPulses.length >= 3) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            _selfEfficacyTrendNote(weeklyPulses),
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildWeeklyFocusSection(List<WeeklyFocus> weeklyFocuses) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'WEEKLY FOCUS (PATIENT-SELECTED)',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1.3),
            1: const pw.FlexColumnWidth(2.7),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Week',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Focus',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Source',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Outcome',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            ...List<WeeklyFocus>.from(weeklyFocuses)
                .toList()
                .take(8)
                .map(
                  (f) {
                final weekLabel = DateFormat('dd MMM yyyy')
                    .format(f.weekStartDate.toLocal());
                final focusText = f.focusText.length > 60
                    ? '${f.focusText.substring(0, 60)}…'
                    : f.focusText;
                final sourceLabel =
                    f.source == WeeklyFocusSource.appGenerated
                        ? 'App suggestion'
                        : 'Patient\'s own';
                String outcomeLabel;
                switch (f.outcome) {
                  case WeeklyFocusOutcome.accepted:
                    outcomeLabel = 'Accepted';
                    break;
                  case WeeklyFocusOutcome.declined:
                    outcomeLabel = 'Declined';
                    break;
                  case WeeklyFocusOutcome.patientEntered:
                    outcomeLabel = 'Patient\'s own';
                    break;
                }
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        weekLabel,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        focusText,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        sourceLabel,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        outcomeLabel,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Weekly focus entries reflect patient-selected behavioural goals. '
          'They are for context only and do not represent clinical recommendations.',
          style: pw.TextStyle(
            fontSize: 8,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildProSection(
    List<ProAssessment> proAssessments,
    String condition,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'VALIDATED QUESTIONNAIRES (POEM / DLQI)',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Validated patient-reported outcome measures collected weekly. '
          'Higher scores indicate greater severity or life impact. Use alongside clinical assessment.',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Date',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Tool',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Score',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Interpretation',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            ...List<ProAssessment>.from(proAssessments)
                .toList()
                .reversed
                .take(8)
                .map(
                  (a) {
                final dateStr =
                    DateFormat('MMM d, yyyy').format(a.date.toLocal());
                final toolLabel = a.type.toUpperCase();
                final scoreLabel =
                    '${a.totalScore}${toolLabel == 'POEM' ? '/28' : toolLabel == 'DLQI' ? '/30' : ''}';
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        dateStr,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        toolLabel,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        scoreLabel,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        a.severityBand,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        if (_poemTrendNote(proAssessments) != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            _poemTrendNote(proAssessments)!,
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ],
        if (_dlqiTrendNote(proAssessments) != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            _dlqiTrendNote(proAssessments)!,
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ],
        if (_dlqiBiologicEligibilityNote(proAssessments, condition) != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            _dlqiBiologicEligibilityNote(proAssessments, condition)!,
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.blue800,
            ),
          ),
        ],
        if (_proTrajectoryNote(proAssessments) != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            _proTrajectoryNote(proAssessments)!,
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.orange800,
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildTriggerProSection(
    List<TriggerProCorrelation> triggerProCorrelations,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TRIGGERS LINKED TO PRO SCORES',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Weekly frequency of trigger categories (stress, sleep, diet, environment) '
          'correlated with validated PRO scores (POEM/DLQI). Positive correlation (r) '
          'means more of the trigger is associated with worse scores.',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Category',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'r (weeks)',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Avg PRO high vs low',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            ...triggerProCorrelations.take(4).map(
                  (c) {
                final rText = '${c.r.toStringAsFixed(2)} (${c.weeks}w)';
                final delta = (c.avgProHigh - c.avgProLow);
                final dir = delta >= 0 ? 'higher' : 'lower';
                final proText =
                    '${c.avgProHigh.toStringAsFixed(1)} vs ${c.avgProLow.toStringAsFixed(1)} ($dir with trigger)';
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        c.category,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        rText,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        proText,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'These are statistical associations observed in your personal data. '
          'They do not prove causation and should not replace medical advice from your dermatologist.',
          style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
        ),
      ],
    );
  }

  static pw.Widget _buildWearableInsightsSection(
    List<DailyWearableAggregate> aggregates,
    List<TriggerProCorrelation> wearableCorrelations,
    String period,
    List<WearableSource>? wearableSources,
  ) {
    // Compute KPIs (reuse existing logic)
    final hrvValues =
        aggregates.where((a) => a.hrvNightly != null).map((a) => a.hrvNightly!);
    final avgHrv =
        hrvValues.isEmpty ? null : hrvValues.reduce((a, b) => a + b) / hrvValues.length;
    final sleepValues = aggregates
        .where((a) => a.totalSleepMinutes != null)
        .map((a) => a.totalSleepMinutes! / 60);
    final avgSleep =
        sleepValues.isEmpty ? null : sleepValues.reduce((a, b) => a + b) / sleepValues.length;
    final lowHrvNights =
        aggregates.where((a) => a.hrvNightly != null && a.hrvNightly! < 40).length;
    final totalHrvNights = hrvValues.length;
    final nightsBelow6h = aggregates
        .where((a) => a.totalSleepMinutes != null && a.totalSleepMinutes! < 360)
        .length;
    final totalSleepNights = sleepValues.length;
    final stepsValues =
        aggregates.where((a) => a.steps != null).map((a) => a.steps!);
    final avgSteps =
        stepsValues.isEmpty ? null : stepsValues.reduce((a, b) => a + b) / stepsValues.length;
    final stepsProvider = _mostCommonProvider(aggregates, hasSteps: true);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'DHealth · Wearable Insights',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              period,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'PASSIVE MONITORING SUMMARY',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Metric',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Value',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Note',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Avg nightly HRV',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    avgHrv != null ? '${avgHrv.toStringAsFixed(0)} ms' : '—',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    '—',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Avg total sleep',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    avgSleep != null ? '${avgSleep.toStringAsFixed(1)} h' : '—',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    totalSleepNights > 0
                        ? '${((nightsBelow6h / totalSleepNights) * 100).toStringAsFixed(0)}% of nights below 6h'
                        : '—',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Low HRV nights',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    '$lowHrvNights/$totalHrvNights',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Nights below 40ms threshold',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    'Avg daily steps',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    avgSteps != null
                        ? NumberFormat('#,##0').format(avgSteps.round())
                        : '—',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    stepsProvider ?? '—',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'WEARABLE–OUTCOME CORRELATIONS',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        if (wearableCorrelations.isEmpty)
          pw.Text(
            'Insufficient data — at least 8 weeks of paired wearable and assessment data required.',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          )
        else
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(0.5),
              3: const pw.FlexColumnWidth(0.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                children: [
                  _tableHeader('Wearable Metric'),
                  _tableHeader('Outcome'),
                  _tableHeader('ρ'),
                  _tableHeader('Weeks'),
                  _tableHeader('Avg (high)'),
                  _tableHeader('Avg (low)'),
                ],
              ),
              ...wearableCorrelations.map((c) {
                final metric = c.category.startsWith('wearable.')
                    ? c.category.substring(9)
                    : c.category;
                return pw.TableRow(
                  children: [
                    _tableCell(metric),
                    _tableCell('PRO'),
                    _tableCell(c.r.toStringAsFixed(2)),
                    _tableCell('${c.weeks}'),
                    _tableCell(c.avgProHigh.toStringAsFixed(1)),
                    _tableCell(c.avgProLow.toStringAsFixed(1)),
                  ],
                );
              }),
            ],
          ),
        pw.SizedBox(height: 20),
        pw.Text(
          'DEVICE & CONSENT',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          _formatDeviceConsent(aggregates, wearableSources),
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.grey100,
          ),
          child: pw.Text(
            'Wearable data is from consumer-grade devices and has not been clinically validated. '
            'Correlations are statistical associations only. For tracking and education purposes. '
            'Not a substitute for clinical assessment.',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildLongitudinalSection(List<DailyLog> logs) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'LONGITUDINAL HEALTH RECORD',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Column(
          children: logs.map((log) {
            final riskScore = log.calculateRiskScore();
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                color: PdfColors.grey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        DateFormat('MMM d • HH:mm').format(log.date),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: riskScore <= 30
                              ? PdfColors.green
                              : riskScore <= 60
                                  ? PdfColors.orange
                                  : PdfColors.red,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(2)),
                        ),
                        child: pw.Text(
                          'R:$riskScore',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Mood:${log.mood}/5 | Itch:${log.itchIntensity}/10 | Stress:${log.stressLevel}/10 | Sleep:${log.sleepQuality}/5',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Lesion: ${log.lesionSeverity.toUpperCase()} | Disrupted: ${log.sleepDisruption ? "Yes" : "No"}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  if (log.affectedAreas.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        'Areas: ${log.affectedAreas.join(", ")}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  if (log.notes.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        'Note: ${log.notes.substring(0, log.notes.length > 60 ? 60 : log.notes.length)}${log.notes.length > 60 ? "..." : ""}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildMetadataUsagePrivacySection(DateTime generatedAt) {
    // REMOVED: Legacy COMPLIANCE & DISCLAIMER block — covered by Part D (Data Provenance)
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DOCUMENT METADATA',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated By:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('DHealth Mobile App'),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Timestamp:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(generatedAt),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Document Type:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('HDR (Health Document Record)'),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'USAGE & SHARING',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '✓ Share with doctors and healthcare providers',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '✓ Use for personal health tracking and insights',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '✓ Keep backup copies for your records',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '✗ Does NOT replace professional medical diagnosis',
              style: pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '✗ Not suitable for emergency medical situations',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'DATA PRIVACY',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Your health data is encrypted and stored securely. You have full ownership and control of your information. '
          'DHealth respects your privacy and complies with ABDM guidelines and India\'s data protection standards.',
          style: pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _buildGovernanceBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'GOVERNANCE',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Consent: This report was generated at the explicit request of the patient named above. '
            'Data sharing with a clinician requires patient-initiated action within the DHealth app.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Intended use: This document is intended for review by a licensed dermatologist or qualified healthcare provider only. '
            'It is not a diagnostic document and does not constitute medical advice.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Data retention: Patient data is retained in accordance with DHealth\'s privacy policy. '
            'Patients may request deletion at any time via the app settings.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Regulatory note: DHealth is a wellness and self-management tool. It is not currently classified as a Software as a Medical '
            'Device (SaMD) in any jurisdiction. Clinical decisions should not be made solely on the basis of this report.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Jurisdiction: Designed for use in India in compliance with ABDM Health Data Management Policy. '
            'For use outside India, applicable local health data regulations apply.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static RedFlagSummary _computeRedFlagSummary(List<DailyLog> logs) {
    if (logs.isEmpty) {
      return const RedFlagSummary(
        events: [],
        totalRedFlagDays: 0,
        mostRecent: null,
        redFlagRate: 0.0,
      );
    }
    final events = <RedFlagEvent>[];
    for (final log in logs) {
      final risk = log.calculateRiskScore();
      final itch = log.itchIntensity;
      final mood = log.mood;
      final disrupted = log.sleepDisruption;

      final triggers = <String>[];
      if (risk >= 85) {
        triggers.add('Risk ≥ 85');
      }
      if (itch >= 9 && (disrupted || mood <= 1)) {
        triggers.add('Itch ≥ 9');
        if (disrupted) triggers.add('Sleep disruption');
        if (mood <= 1) triggers.add('Mood ≤ 1');
      } else if (itch >= 8 && (disrupted || mood <= 2)) {
        triggers.add('Itch ≥ 8');
        if (disrupted) triggers.add('Sleep disruption');
        if (mood <= 2) triggers.add('Mood ≤ 2');
      }
      if (triggers.isNotEmpty) {
        events.add(
          RedFlagEvent(
            date: DateTime(
              log.date.year,
              log.date.month,
              log.date.day,
            ),
            riskScore: risk,
            triggers: triggers.toSet().toList(),
            itch: itch,
            mood: mood,
          ),
        );
      }
    }
    if (events.isEmpty) {
      return const RedFlagSummary(
        events: [],
        totalRedFlagDays: 0,
        mostRecent: null,
        redFlagRate: 0.0,
      );
    }
    events.sort((a, b) => a.date.compareTo(b.date));
    final total = events.length;
    final mostRecent = events.last.date;
    final rate = logs.isEmpty ? 0.0 : total / logs.length;
    final reversedEvents = events.reversed.toList();
    return RedFlagSummary(
      events: reversedEvents,
      totalRedFlagDays: total,
      mostRecent: mostRecent,
      redFlagRate: rate,
    );
  }

  static pw.Widget _buildRedFlagSection(RedFlagSummary summary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RED FLAG EVENTS',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        if (summary.totalRedFlagDays == 0)
          pw.Text(
            'No red flag events recorded in this period.',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          )
        else ...[
          pw.Text(
            '${summary.totalRedFlagDays} red flag day(s) recorded '
            '(${(summary.redFlagRate * 100).toStringAsFixed(0)}% of logged days)'
            '${summary.mostRecent != null ? ' — most recent ${DateFormat('dd MMM yyyy').format(summary.mostRecent!)}' : ''}',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2.4),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(0.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Date',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Risk Score',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Triggers',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Itch',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Mood',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              ...summary.events.take(10).map(
                    (e) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        DateFormat('dd MMM yyyy').format(e.date),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '${e.riskScore}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        e.triggers.join('; '),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '${e.itch}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '${e.mood}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary.events.length > 10) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              '+ ${summary.events.length - 10} earlier event(s) not shown',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Text(
            'Red flag days indicate clinically significant symptom combinations. '
            'This is not a diagnosis. Please review with your dermatologist.',
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ],
    );
  }

  static DataGaps _computeDataGaps(
    List<DailyLog> logs,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (logs.isEmpty) {
      return const DataGaps(
        significantGapCount: 0,
        longestGapDays: 0,
        longestGapStart: null,
        longestGapEnd: null,
      );
    }

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final logDays = <DateTime>{
      for (final log in logs)
        DateTime(log.date.year, log.date.month, log.date.day),
    };

    int currentGap = 0;
    int significantGaps = 0;
    int longestGap = 0;
    DateTime? currentStart;
    DateTime? longestStart;
    DateTime? longestEnd;

    for (DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final hasLog = logDays.contains(d);
      if (!hasLog) {
        if (currentGap == 0) currentStart = d;
        currentGap += 1;
      } else {
        if (currentGap >= 7) {
          significantGaps += 1;
          if (currentGap > longestGap) {
            longestGap = currentGap;
            longestStart = currentStart;
            longestEnd = d.subtract(const Duration(days: 1));
          }
        }
        currentGap = 0;
        currentStart = null;
      }
    }

    // Handle trailing gap at the end of the period.
    if (currentGap >= 7) {
      significantGaps += 1;
      if (currentGap > longestGap) {
        longestGap = currentGap;
        longestStart = currentStart;
        longestEnd = end;
      }
    }

    if (significantGaps == 0) {
      return const DataGaps(
        significantGapCount: 0,
        longestGapDays: 0,
        longestGapStart: null,
        longestGapEnd: null,
      );
    }

    return DataGaps(
      significantGapCount: significantGaps,
      longestGapDays: longestGap,
      longestGapStart: longestStart,
      longestGapEnd: longestEnd,
    );
  }
}

class _LoggingDensity {
  final int loggedDays;
  final int totalDays;

  _LoggingDensity({
    required this.loggedDays,
    required this.totalDays,
  });

  double get percentage =>
      totalDays == 0 ? 0 : (loggedDays / totalDays) * 100.0;
}

class _MedicationAdherencePatterns {
  final int totalExceptions;
  final int missedDoses;
  final int missedDosesLast14Days;
  final int stoppedCount;
  final int changedDoseCount;
  final int sideEffectCount;
  final DateTime? lastExceptionAt;
  final List<String> sideEffectNotes;

  _MedicationAdherencePatterns({
    required this.totalExceptions,
    required this.missedDoses,
    required this.missedDosesLast14Days,
    required this.stoppedCount,
    required this.changedDoseCount,
    required this.sideEffectCount,
    required this.lastExceptionAt,
    required this.sideEffectNotes,
  });
}

class _FlareSummary {
  final int eligibleCount;
  final int unconfirmedCount;
  final DateTime? mostRecentOnset;
  final double? avgDurationDays;

  _FlareSummary({
    required this.eligibleCount,
    required this.unconfirmedCount,
    required this.mostRecentOnset,
    required this.avgDurationDays,
  });
}

