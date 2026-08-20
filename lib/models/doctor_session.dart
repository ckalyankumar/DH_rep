/// Records when a doctor last viewed a patient's data.
///
/// Stored at: users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}/doctorSession/current
class DoctorSession {
  final DateTime viewedAt;
  final String dataScope; // e.g. "logs" or "report"
  final String doctorEmail;

  const DoctorSession({
    required this.viewedAt,
    required this.dataScope,
    required this.doctorEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'viewedAt': viewedAt.toIso8601String(),
      'dataScope': dataScope,
      'doctorEmail': doctorEmail,
    };
  }

  static DoctorSession fromJson(Map<String, dynamic> json) {
    return DoctorSession(
      viewedAt: json['viewedAt'] != null
          ? DateTime.parse(json['viewedAt'] as String)
          : DateTime.now(),
      dataScope: json['dataScope'] as String? ?? 'logs',
      doctorEmail: json['doctorEmail'] as String? ?? '',
    );
  }
}
