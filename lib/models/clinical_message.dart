import 'dart:developer' as developer;

/// A message in the clinically-scoped thread between doctor and patient.
///
/// Stored at: users/{patientId}/sharedWithDoctors/{sanitizedDoctorEmail}/clinicalMessages/{messageId}
class ClinicalMessage {
  static const String unknownSender = 'unknown';
  static const int maxContentLength = 2000;
  static const int counterVisibleRemaining = 200;

  final String id;
  final String sender; // "patient" | "doctor" | [unknownSender]
  final String content;
  final DateTime sentAt;
  final String?
      dataRangeReviewed; // Optional, e.g. "2025-01-01 to 2025-01-30" when doctor sends
  /// True while Firestore has accepted a local write that is not yet on the server.
  final bool hasPendingWrites;

  const ClinicalMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.sentAt,
    this.dataRangeReviewed,
    this.hasPendingWrites = false,
  });

  bool get isFromDoctor => sender == 'doctor';
  bool get isFromPatient => sender == 'patient';
  bool get hasUnknownSender => sender != 'doctor' && sender != 'patient';

  /// Composer counter text. Empty string hides the counter for short messages.
  static String composerCounterText(int length) {
    if (length < maxContentLength - counterVisibleRemaining) return '';
    return '$length/$maxContentLength';
  }

  static String? validateContentLength(String content) {
    if (content.trim().length > maxContentLength) {
      return 'Message exceeds $maxContentLength characters.';
    }
    return null;
  }

  /// Valid senders are only the values [sendMessage] writes. Anything else is
  /// treated as data corruption, not silently attributed to the patient.
  static String normalizedSender(dynamic raw) {
    if (raw == 'patient' || raw == 'doctor') return raw as String;
    developer.log(
      'Malformed clinical message sender: $raw',
      name: 'ClinicalMessage',
    );
    return unknownSender;
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'content': content,
      'sentAt': sentAt.toIso8601String(),
      if (dataRangeReviewed != null) 'dataRangeReviewed': dataRangeReviewed,
    };
  }

  static ClinicalMessage fromJson(Map<String, dynamic> json,
      {required String id}) {
    return ClinicalMessage(
      id: id,
      sender: normalizedSender(json['sender']),
      content: json['content'] as String? ?? '',
      sentAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'] as String)
          : DateTime.now(),
      dataRangeReviewed: json['dataRangeReviewed'] as String?,
    );
  }
}
