import 'package:cloud_firestore/cloud_firestore.dart';

enum FlareCandidateResponse {
  yes,
  notReally,
  remindMeLater,
}

extension FlareCandidateResponseX on FlareCandidateResponse {
  String get jsonValue {
    switch (this) {
      case FlareCandidateResponse.yes:
        return 'yes';
      case FlareCandidateResponse.notReally:
        return 'not_really';
      case FlareCandidateResponse.remindMeLater:
        return 'remind_me_later';
    }
  }

  static FlareCandidateResponse? fromJsonValue(String? value) {
    switch (value) {
      case 'yes':
        return FlareCandidateResponse.yes;
      case 'not_really':
        return FlareCandidateResponse.notReally;
      case 'remind_me_later':
        return FlareCandidateResponse.remindMeLater;
      default:
        return null;
    }
  }
}

class FlareCandidate {
  final String id;
  final String uid;
  final DateTime windowStartDate;
  final DateTime windowEndDate;
  final Map<String, dynamic>? metricsSnapshot;

  final DateTime detectedAt;
  final DateTime? promptedAt;
  final FlareCandidateResponse? response;
  final DateTime? respondedAt;
  final bool patientDismissed;

  FlareCandidate({
    required this.id,
    required this.uid,
    required this.windowStartDate,
    required this.windowEndDate,
    required this.metricsSnapshot,
    required this.detectedAt,
    this.promptedAt,
    this.response,
    this.respondedAt,
    this.patientDismissed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'windowStartDate': _dayStart(windowStartDate).toIso8601String(),
      'windowEndDate': _dayStart(windowEndDate).toIso8601String(),
      if (metricsSnapshot != null) 'metricsSnapshot': metricsSnapshot,
      'detectedAt': detectedAt.toIso8601String(),
      if (promptedAt != null) 'promptedAt': promptedAt!.toIso8601String(),
      if (response != null) 'response': response!.jsonValue,
      if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
      if (patientDismissed) 'patientDismissed': true,
    };
  }

  factory FlareCandidate.fromJson(Map<String, dynamic> json) {
    return FlareCandidate(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      windowStartDate: _parseDateTime(json['windowStartDate']) ?? DateTime.now(),
      windowEndDate: _parseDateTime(json['windowEndDate']) ?? DateTime.now(),
      metricsSnapshot: (json['metricsSnapshot'] as Map?)?.cast<String, dynamic>(),
      detectedAt: _parseDateTime(json['detectedAt']) ?? DateTime.now(),
      promptedAt: _parseDateTime(json['promptedAt']),
      response: FlareCandidateResponseX.fromJsonValue(json['response'] as String?),
      respondedAt: _parseDateTime(json['respondedAt']),
      patientDismissed: json['patientDismissed'] as bool? ?? false,
    );
  }

  FlareCandidate copyWith({
    DateTime? windowEndDate,
    Map<String, dynamic>? metricsSnapshot,
    DateTime? promptedAt,
    FlareCandidateResponse? response,
    DateTime? respondedAt,
    bool? patientDismissed,
  }) {
    return FlareCandidate(
      id: id,
      uid: uid,
      windowStartDate: windowStartDate,
      windowEndDate: windowEndDate ?? this.windowEndDate,
      metricsSnapshot: metricsSnapshot ?? this.metricsSnapshot,
      detectedAt: detectedAt,
      promptedAt: promptedAt ?? this.promptedAt,
      response: response ?? this.response,
      respondedAt: respondedAt ?? this.respondedAt,
      patientDismissed: patientDismissed ?? this.patientDismissed,
    );
  }
}

DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

