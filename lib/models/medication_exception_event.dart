import 'package:cloud_firestore/cloud_firestore.dart';

enum MedicationExceptionType {
  missedDose,
  changedDose,
  stopped,
  sideEffect,
}

extension MedicationExceptionTypeX on MedicationExceptionType {
  String get jsonValue {
    switch (this) {
      case MedicationExceptionType.missedDose:
        return 'missedDose';
      case MedicationExceptionType.changedDose:
        return 'changedDose';
      case MedicationExceptionType.stopped:
        return 'stopped';
      case MedicationExceptionType.sideEffect:
        return 'sideEffect';
    }
  }

  static MedicationExceptionType? fromJsonValue(String? value) {
    switch (value) {
      case 'missedDose':
        return MedicationExceptionType.missedDose;
      case 'changedDose':
        return MedicationExceptionType.changedDose;
      case 'stopped':
        return MedicationExceptionType.stopped;
      case 'sideEffect':
        return MedicationExceptionType.sideEffect;
      default:
        return null;
    }
  }
}

class MedicationExceptionEvent {
  final String id;
  final String uid;
  final MedicationExceptionType type;
  final DateTime occurredAt;
  final DateTime logDate;
  final String? note;
  final String? condition;
  final DateTime createdAt;

  MedicationExceptionEvent({
    required this.id,
    required this.uid,
    required this.type,
    required this.occurredAt,
    required this.logDate,
    this.note,
    this.condition,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'type': type.jsonValue,
      'occurredAt': occurredAt.toIso8601String(),
      'logDate': DateTime(logDate.year, logDate.month, logDate.day).toIso8601String(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      if (condition != null && condition!.trim().isNotEmpty) 'condition': condition!.trim(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MedicationExceptionEvent.fromJson(Map<String, dynamic> json) {
    final type = MedicationExceptionTypeX.fromJsonValue(json['type'] as String?);
    return MedicationExceptionEvent(
      id: json['id'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      type: type ?? MedicationExceptionType.missedDose,
      occurredAt: _parseDateTime(json['occurredAt']) ?? DateTime.now(),
      logDate: _parseDateTime(json['logDate']) ?? DateTime.now(),
      note: json['note'] as String?,
      condition: json['condition'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

