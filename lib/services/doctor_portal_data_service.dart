import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/weekly_self_efficacy_pulse.dart';
import 'package:dhealth/models/pro_assessment.dart';
import 'package:dhealth/models/weekly_focus.dart';
import 'package:dhealth/models/medication_profile.dart';
import 'package:dhealth/debug_agent_log.dart';
import 'package:dhealth/services/doctor_patient_link_service.dart';
import 'package:dhealth/models/flare_event.dart';
import 'package:dhealth/models/medication_exception_event.dart';

/// Provides read-only access to patient data for doctors.
///
/// Uses DoctorPatientLinkService to verify access before fetching.
/// All operations are read-only; doctor view never mutates patient data.
class DoctorPortalDataService {
  final DoctorPatientLinkService _linkService = DoctorPatientLinkService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch patient's daily logs. Verifies doctor has access first.
  Future<List<DailyLog>> getPatientLogs({
    required String patientId,
    required int days,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      // #region agent log
      agentDebugLog(
        location: 'doctor_portal_data_service.dart:getPatientLogs',
        message: 'no doctor email on current user',
        hypothesisId: 'H1',
        data: {'userNull': user == null},
      );
      // #endregion
      return [];
    }

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    // #region agent log
    agentDebugLog(
      location: 'doctor_portal_data_service.dart:getPatientLogs',
      message: 'hasAccess result',
      hypothesisId: 'H1',
      data: {'hasAccess': hasAccess, 'days': days, 'patientIdLen': patientId.length},
    );
    // #endregion
    if (!hasAccess) return [];

    return _fetchLogsForPatient(patientId, days);
  }

  /// Internal: fetch logs from Firestore. Caller must verify access.
  Future<List<DailyLog>> _fetchLogsForPatient(String patientId, int days) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final snap = await _db
          .collection('users')
          .doc(patientId)
          .collection('dailyLogs')
          .where('date', isGreaterThanOrEqualTo: cutoff.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      // #region agent log
      agentDebugLog(
        location: 'doctor_portal_data_service.dart:_fetchLogsForPatient',
        message: 'dailyLogs query ok',
        hypothesisId: 'H2',
        data: {'docCount': snap.docs.length, 'days': days},
      );
      // #endregion
      return snap.docs
          .map((doc) => DailyLog.fromJson(doc.data()))
          .toList();
    } catch (e) {
      // #region agent log
      agentDebugLog(
        location: 'doctor_portal_data_service.dart:_fetchLogsForPatient',
        message: 'dailyLogs query failed (swallowed before)',
        hypothesisId: 'H2',
        data: {
          'errorType': e.runtimeType.toString(),
          'errorBrief':
              e.toString().length > 160 ? e.toString().substring(0, 160) : e.toString(),
        },
      );
      // #endregion
      return [];
    }
  }

  /// Fetch patient's weekly self-efficacy pulses (for doctor report).
  Future<List<WeeklySelfEfficacyPulse>> getPatientPulses({
    required String patientId,
    required int weeks,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return [];

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    if (!hasAccess) return [];

    try {
      final snap = await _db
          .collection('users')
          .doc(patientId)
          .collection('weeklyPulses')
          .get();

      final cutoff = DateTime.now().subtract(Duration(days: weeks * 7));
      final pulses = snap.docs
          .map((d) => WeeklySelfEfficacyPulse.fromJson(d.data(), id: d.id))
          .where((p) => p.weekStartDate.isAfter(cutoff) || p.weekStartDate.isAtSameMomentAs(cutoff))
          .toList();
      pulses.sort((a, b) => a.weekStartDate.compareTo(b.weekStartDate));
      return pulses;
    } catch (e) {
      return [];
    }
  }

  /// Fetch patient's validated PRO assessments (POEM, DLQI) for a recent window.
  Future<List<ProAssessment>> getPatientProAssessments({
    required String patientId,
    required int days,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return [];

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    if (!hasAccess) return [];

    try {
      final snap = await _db
          .collection('users')
          .doc(patientId)
          .collection('proAssessments')
          .get();

      final cutoff = DateTime.now().subtract(Duration(days: days));
      final pros = snap.docs
          .map((d) => ProAssessment.fromJson(d.data(), id: d.id))
          .where((p) => p.date.isAfter(cutoff) || p.date.isAtSameMomentAs(cutoff))
          .toList();
      pros.sort((a, b) => a.date.compareTo(b.date));
      return pros;
    } catch (e) {
      return [];
    }
  }

  /// Fetch patient's weekly focus entries for clinician context.
  Future<List<WeeklyFocus>> getPatientWeeklyFocus({
    required String patientId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return [];

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    if (!hasAccess) return [];

    try {
      final snap = await _db
          .collection('users')
          .doc(patientId)
          .collection('weeklyFocus')
          .get();

      final focuses = snap.docs
          .map((d) => WeeklyFocus.fromJson(d.data(), id: d.id))
          .toList();
      focuses.sort(
        (a, b) => b.weekStartDate.compareTo(a.weekStartDate),
      );
      return focuses;
    } catch (e) {
      return [];
    }
  }

  /// Fetch patient's medication profile for treatment context.
  Future<MedicationProfile?> getPatientMedicationProfile({
    required String patientId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    if (!hasAccess) return null;

    try {
      final doc = await _db
          .collection('users')
          .doc(patientId)
          .collection('medicationProfile')
          .doc('profile')
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      data['uid'] ??= patientId;
      return MedicationProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Fetch patient's medication exception events (missed dose / stop / change / side effects).
  Future<List<MedicationExceptionEvent>> getPatientMedicationExceptions({
    required String patientId,
    required int days,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return [];

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    if (!hasAccess) return [];

    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final snap = await _db
          .collection('users')
          .doc(patientId)
          .collection('medicationExceptions')
          .where('occurredAt', isGreaterThanOrEqualTo: cutoff.toIso8601String())
          .orderBy('occurredAt', descending: true)
          .get();

      return snap.docs
          .map((d) => MedicationExceptionEvent.fromJson(d.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch patient's flare events for report context.
  Future<List<FlareEvent>> getPatientFlareEvents({
    required String patientId,
    required int days,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return [];

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    if (!hasAccess) return [];

    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final snap = await _db
          .collection('users')
          .doc(patientId)
          .collection('flareEvents')
          .where('onsetDate', isGreaterThanOrEqualTo: cutoff.toIso8601String())
          .orderBy('onsetDate', descending: true)
          .get();

      return snap.docs.map((d) => FlareEvent.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch a lightweight snapshot of the patient's profile document.
  ///
  /// Returns the full users/{patientId} document data after verifying doctor access.
  /// Caller can read profile-specific fields like profile.dateOfBirth / profile.abhaId.
  Future<Map<String, dynamic>?> getPatientProfile({
    required String patientId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return null;

    final hasAccess = await _linkService.hasAccess(
      patientId: patientId,
      doctorEmail: user!.email!,
    );
    if (!hasAccess) return null;

    try {
      final doc = await _db.collection('users').doc(patientId).get();
      if (!doc.exists) return null;
      // #region agent log
      agentDebugLog(
        location: 'doctor_portal_data_service.dart:getPatientProfile',
        message: 'profile doc fetched',
        hypothesisId: 'H2',
        data: {'hasData': doc.data() != null, 'patientIdLen': patientId.length},
      );
      // #endregion
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Default display name when patient has not set one.
  static String defaultPatientName(String? condition) {
    if (condition != null && condition.isNotEmpty) {
      return 'Patient ($condition)';
    }
    return 'Patient';
  }
}
