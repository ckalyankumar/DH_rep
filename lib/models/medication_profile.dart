import 'package:cloud_firestore/cloud_firestore.dart';

enum MedicationTreatmentType {
  topical,
  systemic,
  biologic,
  combinationTherapy,
  none,
}

extension MedicationTreatmentTypeX on MedicationTreatmentType {
  String get displayLabel {
    switch (this) {
      case MedicationTreatmentType.topical:
        return 'Topical therapy';
      case MedicationTreatmentType.systemic:
        return 'Systemic therapy';
      case MedicationTreatmentType.biologic:
        return 'Biologic therapy';
      case MedicationTreatmentType.combinationTherapy:
        return 'Combination therapy';
      case MedicationTreatmentType.none:
        return 'No current treatment';
    }
  }

  String get jsonValue {
    switch (this) {
      case MedicationTreatmentType.topical:
        return 'topical';
      case MedicationTreatmentType.systemic:
        return 'systemic';
      case MedicationTreatmentType.biologic:
        return 'biologic';
      case MedicationTreatmentType.combinationTherapy:
        return 'combinationTherapy';
      case MedicationTreatmentType.none:
        return 'none';
    }
  }

  static MedicationTreatmentType fromJsonValue(String? value) {
    switch (value) {
      case 'topical':
        return MedicationTreatmentType.topical;
      case 'systemic':
        return MedicationTreatmentType.systemic;
      case 'biologic':
        return MedicationTreatmentType.biologic;
      case 'combinationTherapy':
        return MedicationTreatmentType.combinationTherapy;
      case 'none':
      default:
        return MedicationTreatmentType.none;
    }
  }
}

class MedicationProfile {
  final String uid;
  final MedicationTreatmentType treatmentType;
  final String? medicationName; // optional, free text, max 60 chars (enforced at UI)
  final DateTime? startDate;
  final DateTime updatedAt;

  MedicationProfile({
    required this.uid,
    required this.treatmentType,
    this.medicationName,
    this.startDate,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'treatmentType': treatmentType.jsonValue,
      if (medicationName != null) 'medicationName': medicationName,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MedicationProfile.fromJson(Map<String, dynamic> json) {
    return MedicationProfile(
      uid: json['uid'] as String? ?? '',
      treatmentType: MedicationTreatmentTypeX.fromJsonValue(
        json['treatmentType'] as String?,
      ),
      medicationName: json['medicationName'] as String?,
      startDate: _parseDateTime(json['startDate']),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  MedicationProfile copyWith({
    String? uid,
    MedicationTreatmentType? treatmentType,
    String? medicationName,
    DateTime? startDate,
    DateTime? updatedAt,
  }) {
    return MedicationProfile(
      uid: uid ?? this.uid,
      treatmentType: treatmentType ?? this.treatmentType,
      medicationName: medicationName ?? this.medicationName,
      startDate: startDate ?? this.startDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.parse(value);
  return null;
}

