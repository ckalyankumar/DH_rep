/// A message in the clinically-scoped thread between doctor and patient.
///
/// Stored at: users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}/clinicalMessages/{messageId}
class ClinicalMessage {
  final String id;
  final String sender; // "patient" | "doctor"
  final String content;
  final DateTime sentAt;
  final String? dataRangeReviewed; // Optional, e.g. "2025-01-01 to 2025-01-30" when doctor sends

  const ClinicalMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.sentAt,
    this.dataRangeReviewed,
  });

  bool get isFromDoctor => sender == 'doctor';
  bool get isFromPatient => sender == 'patient';

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'content': content,
      'sentAt': sentAt.toIso8601String(),
      if (dataRangeReviewed != null) 'dataRangeReviewed': dataRangeReviewed,
    };
  }

  static ClinicalMessage fromJson(Map<String, dynamic> json, {required String id}) {
    return ClinicalMessage(
      id: id,
      sender: json['sender'] as String? ?? 'patient',
      content: json['content'] as String? ?? '',
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'] as String)
          : DateTime.now(),
      dataRangeReviewed: json['dataRangeReviewed'] as String?,
    );
  }
}
