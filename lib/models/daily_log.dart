import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLog {
  final String id;
  final String condition;
  final int mood; // 1-5 scale
  final int itchIntensity; // 0-10
  final int stressLevel; // 0-10
  final String lesionSeverity; // 'none', 'mild', 'moderate', 'severe'
  final List<String> affectedAreas;
  final int sleepQuality; // 1-5 scale
  final bool sleepDisruption;
  final String notes;
  final DateTime date;
  final List<String>? triggers;
  final DateTime? createdAt;
  final List<String>? structuredTriggerIds;

  // Treatment context (optional; durable adherence exceptions live in a separate collection)
  final String? treatmentNoteAction; // 'allGood'|'missedDose'|'sideEffect'|'changedDose'|'stopped'
  final String? treatmentNoteText;

  // Wearable-derived fields (optional, backward-compatible)
  final double? wearableSleepQuality; // totalSleepMinutes/480 * 5 → 0–5 scale
  final bool? wearableSleepDisruption; // awakenings >= 3
  final double? wearableHrv;
  final int? wearableSteps;
  final bool hasWearableData;

  // ── WEARABLE PREFILL AUDIT ─────────────────────────────────────
  // Raw values from the wearable at the time of check-in.
  // These are NEVER overwritten by user interaction after save.
  final double? wearableRawSleepMinutes; // e.g. 347.0
  final int? wearableRawAwakenings; // e.g. 4
  final double? wearableRawDeviceStress; // Garmin only, 0–100
  final String? wearableProvider; // "fitbit" | "garmin" | "oura" etc.
  final DateTime? wearablePrefillSyncedAt; // when the wearable data was synced

  // Override flags — true if user changed the pre-filled value before saving.
  // Used to measure prefill accuracy and tune derivation thresholds over time.
  final bool sleepQualityWasOverridden; // default: false
  final bool sleepDisruptionWasOverridden; // default: false
  final bool stressWasOverridden; // default: false

  bool get hasWearablePrefill => wearableProvider != null;

  DailyLog({
    required this.id,
    required this.condition,
    required this.mood,
    required this.itchIntensity,
    required this.stressLevel,
    required this.lesionSeverity,
    required this.affectedAreas,
    required this.sleepQuality,
    required this.sleepDisruption,
    required this.notes,
    required this.date,
    this.triggers,
    this.createdAt,
    this.structuredTriggerIds,
    this.treatmentNoteAction,
    this.treatmentNoteText,
    this.wearableSleepQuality,
    this.wearableSleepDisruption,
    this.wearableHrv,
    this.wearableSteps,
    this.hasWearableData = false,
    this.wearableRawSleepMinutes,
    this.wearableRawAwakenings,
    this.wearableRawDeviceStress,
    this.wearableProvider,
    this.wearablePrefillSyncedAt,
    this.sleepQualityWasOverridden = false,
    this.sleepDisruptionWasOverridden = false,
    this.stressWasOverridden = false,
  });

  /// Calculate severity score (0-100) - used for reports
  int get severityScore => calculateRiskScore();

  /// Calculate risk score (0-100) based on all health factors
  int calculateRiskScore() {
    int score = 0;
    
    // Mood factor: lower mood = higher risk (5 = excellent, 1 = poor)
    score += ((5 - mood) * 6); // 0-24 points
    
    // Itch factor: direct contribution
    score += (itchIntensity * 2.5).toInt(); // 0-25 points
    
    // Stress factor
    score += (stressLevel * 2).toInt(); // 0-20 points
    
    // Lesion severity
    switch (lesionSeverity) {
      case 'severe':
        score += 15;
        break;
      case 'moderate':
        score += 10;
        break;
      case 'mild':
        score += 5;
        break;
      default:
        score += 0;
    }
    
    // Sleep quality (1-5 scale)
    score += ((5 - sleepQuality) * 2); // 0-8 points
    
    // Sleep disruption
    if (sleepDisruption) score += 5;
    
    // Affected body areas (count)
    score += (affectedAreas.length * 2).clamp(0, 8);
    
    // Cap at 100
    return score > 100 ? 100 : score;
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condition': condition,
      'mood': mood,
      'itchIntensity': itchIntensity,
      'stressLevel': stressLevel,
      'lesionSeverity': lesionSeverity,
      'affectedAreas': affectedAreas,
      'sleepQuality': sleepQuality,
      'sleepDisruption': sleepDisruption,
      'notes': notes,
      'date': date.toIso8601String(),
      'triggers': triggers,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      if (structuredTriggerIds != null)
        'structuredTriggerIds': structuredTriggerIds,
      if (treatmentNoteAction != null) 'treatmentNoteAction': treatmentNoteAction,
      if (treatmentNoteText != null && treatmentNoteText!.trim().isNotEmpty)
        'treatmentNoteText': treatmentNoteText!.trim(),
      if (wearableSleepQuality != null) 'wearableSleepQuality': wearableSleepQuality,
      if (wearableSleepDisruption != null) 'wearableSleepDisruption': wearableSleepDisruption,
      if (wearableHrv != null) 'wearableHrv': wearableHrv,
      if (wearableSteps != null) 'wearableSteps': wearableSteps,
      'hasWearableData': hasWearableData,
      if (wearableRawSleepMinutes != null) 'wearableRawSleepMinutes': wearableRawSleepMinutes,
      if (wearableRawAwakenings != null) 'wearableRawAwakenings': wearableRawAwakenings,
      if (wearableRawDeviceStress != null) 'wearableRawDeviceStress': wearableRawDeviceStress,
      if (wearableProvider != null) 'wearableProvider': wearableProvider,
      if (wearablePrefillSyncedAt != null)
        'wearablePrefillSyncedAt': wearablePrefillSyncedAt!.toIso8601String(),
      if (sleepQualityWasOverridden) 'sleepQualityWasOverridden': true,
      if (sleepDisruptionWasOverridden) 'sleepDisruptionWasOverridden': true,
      if (stressWasOverridden) 'stressWasOverridden': true,
    };
  }

  /// Create from JSON
  static DailyLog fromJson(Map<String, dynamic> json) {
    return DailyLog(
      id: json['id'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      mood: json['mood'] as int? ?? 3,
      itchIntensity: json['itchIntensity'] as int? ?? 0,
      stressLevel: json['stressLevel'] as int? ?? 0,
      lesionSeverity: json['lesionSeverity'] as String? ?? 'none',
      affectedAreas: json['affectedAreas'] != null
          ? List<String>.from(json['affectedAreas'] as List)
          : [],
      sleepQuality: json['sleepQuality'] as int? ?? 3,
      sleepDisruption: json['sleepDisruption'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      triggers: json['triggers'] != null
          ? List<String>.from(json['triggers'] as List)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      structuredTriggerIds:
          (json['structuredTriggerIds'] as List<dynamic>?)?.cast<String>(),
      treatmentNoteAction: json['treatmentNoteAction'] as String?,
      treatmentNoteText: json['treatmentNoteText'] as String?,
      wearableSleepQuality: (json['wearableSleepQuality'] as num?)?.toDouble(),
      wearableSleepDisruption: json['wearableSleepDisruption'] as bool?,
      wearableHrv: (json['wearableHrv'] as num?)?.toDouble(),
      wearableSteps: json['wearableSteps'] as int?,
      hasWearableData: json['hasWearableData'] as bool? ?? false,
      wearableRawSleepMinutes: (json['wearableRawSleepMinutes'] as num?)?.toDouble(),
      wearableRawAwakenings: json['wearableRawAwakenings'] as int?,
      wearableRawDeviceStress: (json['wearableRawDeviceStress'] as num?)?.toDouble(),
      wearableProvider: json['wearableProvider'] as String?,
      wearablePrefillSyncedAt: _parseDateTime(json['wearablePrefillSyncedAt']),
      sleepQualityWasOverridden: json['sleepQualityWasOverridden'] as bool? ?? false,
      sleepDisruptionWasOverridden: json['sleepDisruptionWasOverridden'] as bool? ?? false,
      stressWasOverridden: json['stressWasOverridden'] as bool? ?? false,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  /// Create a copy with optional replacements
  DailyLog copyWith({
    String? id,
    String? condition,
    int? mood,
    int? itchIntensity,
    int? stressLevel,
    String? lesionSeverity,
    List<String>? affectedAreas,
    int? sleepQuality,
    bool? sleepDisruption,
    String? notes,
    DateTime? date,
    List<String>? triggers,
    DateTime? createdAt,
    List<String>? structuredTriggerIds,
    String? treatmentNoteAction,
    String? treatmentNoteText,
    double? wearableSleepQuality,
    bool? wearableSleepDisruption,
    double? wearableHrv,
    int? wearableSteps,
    bool? hasWearableData,
    double? wearableRawSleepMinutes,
    int? wearableRawAwakenings,
    double? wearableRawDeviceStress,
    String? wearableProvider,
    DateTime? wearablePrefillSyncedAt,
    bool? sleepQualityWasOverridden,
    bool? sleepDisruptionWasOverridden,
    bool? stressWasOverridden,
  }) {
    return DailyLog(
      id: id ?? this.id,
      condition: condition ?? this.condition,
      mood: mood ?? this.mood,
      itchIntensity: itchIntensity ?? this.itchIntensity,
      stressLevel: stressLevel ?? this.stressLevel,
      lesionSeverity: lesionSeverity ?? this.lesionSeverity,
      affectedAreas: affectedAreas ?? this.affectedAreas,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      sleepDisruption: sleepDisruption ?? this.sleepDisruption,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      triggers: triggers ?? this.triggers,
      createdAt: createdAt ?? this.createdAt,
      structuredTriggerIds:
          structuredTriggerIds ?? this.structuredTriggerIds,
      treatmentNoteAction: treatmentNoteAction ?? this.treatmentNoteAction,
      treatmentNoteText: treatmentNoteText ?? this.treatmentNoteText,
      wearableSleepQuality: wearableSleepQuality ?? this.wearableSleepQuality,
      wearableSleepDisruption: wearableSleepDisruption ?? this.wearableSleepDisruption,
      wearableHrv: wearableHrv ?? this.wearableHrv,
      wearableSteps: wearableSteps ?? this.wearableSteps,
      hasWearableData: hasWearableData ?? this.hasWearableData,
      wearableRawSleepMinutes: wearableRawSleepMinutes ?? this.wearableRawSleepMinutes,
      wearableRawAwakenings: wearableRawAwakenings ?? this.wearableRawAwakenings,
      wearableRawDeviceStress: wearableRawDeviceStress ?? this.wearableRawDeviceStress,
      wearableProvider: wearableProvider ?? this.wearableProvider,
      wearablePrefillSyncedAt: wearablePrefillSyncedAt ?? this.wearablePrefillSyncedAt,
      sleepQualityWasOverridden: sleepQualityWasOverridden ?? this.sleepQualityWasOverridden,
      sleepDisruptionWasOverridden: sleepDisruptionWasOverridden ?? this.sleepDisruptionWasOverridden,
      stressWasOverridden: stressWasOverridden ?? this.stressWasOverridden,
    );
  }

  @override
  String toString() =>
      'DailyLog(id: $id, mood: $mood, itch: $itchIntensity, severity: ${calculateRiskScore()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyLog && other.id == id && other.date == date;
  }

  @override
  int get hashCode => id.hashCode ^ date.hashCode;
}
