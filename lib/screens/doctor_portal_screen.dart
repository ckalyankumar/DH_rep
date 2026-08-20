import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/services/doctor_portal_data_service.dart';
import 'package:dhealth/services/insight_engine.dart';
import 'package:dhealth/services/insight_models.dart';
import 'package:dhealth/services/report_generator_service.dart';
import 'package:dhealth/utils/file_download_helper.dart';
import 'package:dhealth/screens/doctor_clinical_thread_screen.dart';

/// Doctor portal: read-only list of patients who shared access with this doctor.
///
/// Pilot behavior: generate PDF on demand; no persisted Storage URL required.
class DoctorPortalScreen extends StatefulWidget {
  const DoctorPortalScreen({super.key});

  @override
  State<DoctorPortalScreen> createState() => _DoctorPortalScreenState();
}

class _DoctorPortalScreenState extends State<DoctorPortalScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DoctorPortalDataService _dataService = DoctorPortalDataService();

  final Map<String, String> _displayNameByPatientId = {};
  final Map<String, bool> _busyByPatientId = {};

  User? get _user => FirebaseAuth.instance.currentUser;

  Query<Map<String, dynamic>>? get _linksQuery {
    final email = _user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    return _db
        .collectionGroup('sharedWithDoctors')
        .where('doctorEmail', isEqualTo: email)
        .where('status', isEqualTo: 'active');
  }

  Future<String> _getPatientDisplayName(String patientId) async {
    final cached = _displayNameByPatientId[patientId];
    if (cached != null) return cached;
    try {
      final snap = await _db.collection('users').doc(patientId).get();
      final data = snap.data();
      final profile = data?['profile'];
      String? name;
      if (profile is Map) {
        final raw = profile['displayName'];
        if (raw is String && raw.trim().isNotEmpty) {
          name = raw.trim();
        }
      }
      final resolved = name ?? 'Patient';
      _displayNameByPatientId[patientId] = resolved;
      return resolved;
    } catch (_) {
      const resolved = 'Patient';
      _displayNameByPatientId[patientId] = resolved;
      return resolved;
    }
  }

  void _setBusy(String patientId, bool busy) {
    if (!mounted) return;
    setState(() {
      _busyByPatientId[patientId] = busy;
    });
  }

  Future<void> _downloadReportForPatient({
    required String patientId,
    required String doctorEmail,
  }) async {
    _setBusy(patientId, true);
    try {
      final displayName = await _getPatientDisplayName(patientId);

      // Use a wide window so the report is useful in pilots.
      final logs = await _dataService.getPatientLogs(patientId: patientId, days: 365);
      if (logs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No patient logs available yet.')),
        );
        return;
      }

      final pros = await _dataService.getPatientProAssessments(patientId: patientId, days: 365);
      final pulses = await _dataService.getPatientPulses(patientId: patientId, weeks: 12);
      final medicationProfile = await _dataService.getPatientMedicationProfile(patientId: patientId);
      final medicationExceptions =
          await _dataService.getPatientMedicationExceptions(patientId: patientId, days: 365);
      final flareEvents = await _dataService.getPatientFlareEvents(patientId: patientId, days: 365);

      final sortedLogs = List<DailyLog>.from(logs)..sort((a, b) => a.date.compareTo(b.date));
      final startDate = sortedLogs.first.date;
      final endDate = sortedLogs.last.date;
      final condition = sortedLogs.isNotEmpty
          ? sortedLogs.first.condition
          : (pros.isNotEmpty ? pros.first.condition : 'psoriasis');

      final correlations = pros.isEmpty
          ? <TriggerProCorrelation>[]
          : TriggerProCorrelationEngine.correlate(sortedLogs, pros);

      final profileDoc =
          await _dataService.getPatientProfile(patientId: patientId);
      DateTime? patientDob;
      String? patientAbhaId;
      try {
        final profile = profileDoc?['profile'];
        if (profile is Map) {
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
        patientName: displayName,
        condition: condition,
        logs: sortedLogs,
        startDate: startDate,
        endDate: endDate,
        medicationProfile: medicationProfile,
        medicationExceptions: medicationExceptions.isNotEmpty ? medicationExceptions : null,
        flareEvents: flareEvents.isNotEmpty ? flareEvents : null,
        weeklyPulses: pulses.isNotEmpty ? pulses : null,
        proAssessments: pros.isNotEmpty ? pros : null,
        triggerProCorrelations: correlations.isNotEmpty ? correlations : null,
        patientDateOfBirth: patientDob,
        patientAbhaId: patientAbhaId,
      );

      final bytes = await doc.save();
      final filename = 'dhealth_report_$patientId.pdf';
      final path = await saveBytesToFile(bytes, filename, mimeType: 'application/pdf');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path.startsWith('downloaded:') ? 'PDF downloaded' : 'PDF saved to $path'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    } finally {
      _setBusy(patientId, false);
    }
  }

  Future<void> _openMessageThread({
    required String patientId,
    required String doctorEmail,
  }) async {
    _setBusy(patientId, true);
    try {
      final displayName = await _getPatientDisplayName(patientId);
      final logs = await _dataService.getPatientLogs(patientId: patientId, days: 365);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoctorClinicalThreadScreen(
            patientId: patientId,
            patientDisplayName: displayName,
            doctorEmail: doctorEmail,
            logs: logs,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open thread: $e')),
      );
    } finally {
      _setBusy(patientId, false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final email = user?.email?.trim().toLowerCase();
    final query = _linksQuery;

    if (user == null || email == null || email.isEmpty || query == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Patients')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sign in as a doctor to view patients.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Patients'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading patients: ${snapshot.error}'),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];
                final patientIds = <String>{};
                for (final d in docs) {
                  final patientId = (d.data()['patientId'] as String?)?.trim();
                  if (patientId != null && patientId.isNotEmpty) {
                    patientIds.add(patientId);
                    continue;
                  }
                  final segments = d.reference.path.split('/');
                  if (segments.length >= 2 && segments.first == 'users') {
                    patientIds.add(segments[1]);
                  }
                }
                final patients = patientIds.toList()..sort();

                if (patients.isEmpty) {
                  return const _EmptyState();
                }

                final doctorEmail = email;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: patients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final patientId = patients[index];
                    final busy = _busyByPatientId[patientId] ?? false;

                    return FutureBuilder<String>(
                      future: _getPatientDisplayName(patientId),
                      builder: (context, nameSnap) {
                        final name = nameSnap.data ?? 'Patient';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => _downloadReportForPatient(
                                                  patientId: patientId,
                                                  doctorEmail: doctorEmail,
                                                ),
                                        icon: busy
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.download),
                                        label: const Text('Download Report'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => _openMessageThread(
                                                patientId: patientId,
                                                doctorEmail: doctorEmail,
                                              ),
                                      icon: const Icon(Icons.chat_bubble_outline),
                                      label: const Text('Message'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const _ReadOnlyFooter(),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔗', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text(
              'No patients yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Patients will appear here once they share their data with you from the dHealth app.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyFooter extends StatelessWidget {
  const _ReadOnlyFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        'Read-only · You can only see patients who have shared access with you.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
