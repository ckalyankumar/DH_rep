import 'package:cloud_firestore/cloud_firestore.dart';

enum WeeklyFocusSource { appGenerated, patientEntered }

enum WeeklyFocusOutcome { accepted, declined, patientEntered }

class WeeklyFocus {
  final String id; // UUID
  final String uid; // patient user ID
  final DateTime weekStartDate; // Monday of the week (normalized to midnight)
  final String condition; // 'psoriasis' or 'eczema'
  final WeeklyFocusSource source; // appGenerated | patientEntered
  final String focusText; // suggestion text shown to / entered by patient
  final String? recommendationId; // linked recommendation ID if app-generated
  final String? triggerCategory; // e.g. 'stress', 'sleep', 'diet', 'environment'
  final WeeklyFocusOutcome outcome; // accepted | declined | patientEntered
  final DateTime createdAt;

  WeeklyFocus({
    required this.id,
    required this.uid,
    required this.weekStartDate,
    required this.condition,
    required this.source,
    required this.focusText,
    this.recommendationId,
    this.triggerCategory,
    required this.outcome,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'weekStartDate': weekStartDate.toIso8601String(),
      'condition': condition,
      'source': source.name,
      'focusText': focusText,
      if (recommendationId != null) 'recommendationId': recommendationId,
      if (triggerCategory != null) 'triggerCategory': triggerCategory,
      'outcome': outcome.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static WeeklyFocus fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) {
    return WeeklyFocus(
      id: id,
      uid: json['uid'] as String? ?? '',
      weekStartDate: _parseDateTime(json['weekStartDate']) ?? DateTime.now().toUtc(),
      condition: json['condition'] as String? ?? '',
      source: _parseSource(json['source']),
      focusText: json['focusText'] as String? ?? '',
      recommendationId: json['recommendationId'] as String?,
      triggerCategory: json['triggerCategory'] as String?,
      outcome: _parseOutcome(json['outcome']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  static DateTime currentWeekStart() {
    final now = DateTime.now(); // local time
    final daysSinceMonday = now.weekday - DateTime.monday;
    final localMonday = DateTime(
      now.year,
      now.month,
      now.day - daysSinceMonday,
    );
    return DateTime.utc(
      localMonday.year,
      localMonday.month,
      localMonday.day,
    );
  }

  static WeeklyFocusSource _parseSource(dynamic value) {
    final str = (value as String?) ?? WeeklyFocusSource.appGenerated.name;
    switch (str) {
      case 'patientEntered':
        return WeeklyFocusSource.patientEntered;
      case 'appGenerated':
      default:
        return WeeklyFocusSource.appGenerated;
    }
  }

  static WeeklyFocusOutcome _parseOutcome(dynamic value) {
    final str = (value as String?) ?? WeeklyFocusOutcome.accepted.name;
    switch (str) {
      case 'declined':
        return WeeklyFocusOutcome.declined;
      case 'patientEntered':
        return WeeklyFocusOutcome.patientEntered;
      case 'accepted':
      default:
        return WeeklyFocusOutcome.accepted;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is String) return DateTime.parse(value).toUtc();
    return null;
  }
}

