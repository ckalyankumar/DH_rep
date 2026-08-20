import 'package:cloud_firestore/cloud_firestore.dart';

enum FlareEventSource {
  confirmedHybrid,
  algorithmUnconfirmed,
  patientInitiated,
}

extension FlareEventSourceX on FlareEventSource {
  String get jsonValue {
    switch (this) {
      case FlareEventSource.confirmedHybrid:
        return 'confirmed_hybrid';
      case FlareEventSource.algorithmUnconfirmed:
        return 'algorithm_unconfirmed';
      case FlareEventSource.patientInitiated:
        return 'patient_initiated';
    }
  }

  static FlareEventSource fromJsonValue(String? value) {
    switch (value) {
      case 'confirmed_hybrid':
        return FlareEventSource.confirmedHybrid;
      case 'algorithm_unconfirmed':
        return FlareEventSource.algorithmUnconfirmed;
      case 'patient_initiated':
        return FlareEventSource.patientInitiated;
      default:
        return FlareEventSource.algorithmUnconfirmed;
    }
  }
}

class FlareEvent {
  final String id;
  final String uid;
  final DateTime onsetDate;
  final DateTime? resolutionDate;
  final FlareEventSource source;
  final Map<String, dynamic>? metricsSnapshot;
  final String? candidateId;
  final DateTime createdAt;
  final DateTime updatedAt;

  FlareEvent({
    required this.id,
    required this.uid,
    required this.onsetDate,
    this.resolutionDate,
    required this.source,
    this.metricsSnapshot,
    this.candidateId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOutcomeEligible =>
      source == FlareEventSource.confirmedHybrid ||
      source == FlareEventSource.patientInitiated;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'onsetDate': _dayStart(onsetDate).toIso8601String(),
      if (resolutionDate != null)
        'resolutionDate': _dayStart(resolutionDate!).toIso8601String(),
      'source': source.jsonValue,
      if (candidateId != null) 'candidateId': candidateId,
      if (metricsSnapshot != null) 'metricsSnapshot': metricsSnapshot,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FlareEvent.fromJson(Map<String, dynamic> json) {
    return FlareEvent(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      onsetDate: _parseDateTime(json['onsetDate']) ?? DateTime.now(),
      resolutionDate: _parseDateTime(json['resolutionDate']),
      source: FlareEventSourceX.fromJsonValue(json['source'] as String?),
      metricsSnapshot: (json['metricsSnapshot'] as Map?)?.cast<String, dynamic>(),
      candidateId: json['candidateId'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  FlareEvent copyWith({
    DateTime? resolutionDate,
    Map<String, dynamic>? metricsSnapshot,
    DateTime? updatedAt,
  }) {
    return FlareEvent(
      id: id,
      uid: uid,
      onsetDate: onsetDate,
      resolutionDate: resolutionDate ?? this.resolutionDate,
      source: source,
      metricsSnapshot: metricsSnapshot ?? this.metricsSnapshot,
      candidateId: candidateId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
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

