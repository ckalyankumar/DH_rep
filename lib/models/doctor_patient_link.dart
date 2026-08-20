/// Link between a patient and a doctor, created when the patient grants
/// explicit consent for that doctor to view their data.
///
/// Patient controls access via share (email) and revocation.
/// Doctor view is always read-only on patient logs.
class DoctorPatientLink {
  final String id;
  final String patientId;
  final String? patientDisplayName;
  final String doctorEmail;
  final LinkStatus status;
  final DateTime createdAt;
  final DateTime consentedAt;
  final DateTime? revokedAt;

  const DoctorPatientLink({
    required this.id,
    required this.patientId,
    this.patientDisplayName,
    required this.doctorEmail,
    required this.status,
    required this.createdAt,
    required this.consentedAt,
    this.revokedAt,
  });

  bool get isActive => status == LinkStatus.active;

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'patientDisplayName': patientDisplayName,
      'doctorEmail': doctorEmail,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'consentedAt': consentedAt.toIso8601String(),
      if (revokedAt != null) 'revokedAt': revokedAt!.toIso8601String(),
    };
  }

  static DoctorPatientLink fromJson(Map<String, dynamic> json, {required String id}) {
    return DoctorPatientLink(
      id: id,
      patientId: json['patientId'] as String,
      patientDisplayName: json['patientDisplayName'] as String?,
      doctorEmail: json['doctorEmail'] as String,
      status: LinkStatus.values.byName(json['status'] as String? ?? 'active'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      consentedAt: json['consentedAt'] != null
          ? DateTime.parse(json['consentedAt'] as String)
          : DateTime.now(),
      revokedAt: json['revokedAt'] != null
          ? DateTime.parse(json['revokedAt'] as String)
          : null,
    );
  }
}

enum LinkStatus {
  active,
  revoked,
  pending,
}
