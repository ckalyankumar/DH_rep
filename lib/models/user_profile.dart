import 'package:intl/intl.dart';

class UserProfile {
  String userId;
  String? name;
  String selectedCondition; // 'psoriasis' or 'eczema'
  DateTime createdAt;
  DateTime lastUpdated;
  int currentStreak;
  int longestStreak;
  DateTime? lastLogDate;
  DateTime? dateOfBirth;
  String? abhaId;

  UserProfile({
    required this.userId,
    this.name,
    required this.selectedCondition,
    required this.createdAt,
    required this.lastUpdated,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLogDate,
    this.dateOfBirth,
    this.abhaId,
  });

  Map<String, dynamic> toMap() {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    return {
      'userId': userId,
      'name': name,
      'selectedCondition': selectedCondition,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastLogDate': lastLogDate?.toIso8601String(),
      'dateOfBirth':
          dateOfBirth != null ? dateFormatter.format(dateOfBirth!) : null,
      'abhaId': abhaId,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parseDob(dynamic value) {
      if (value == null) return null;
      try {
        // Expecting a yyyy-MM-dd date-only string.
        return DateFormat('yyyy-MM-dd').parse(value as String);
      } catch (_) {
        return null;
      }
    }

    return UserProfile(
      userId: map['userId'],
      name: map['name'],
      selectedCondition: map['selectedCondition'],
      createdAt: DateTime.parse(map['createdAt']),
      lastUpdated: DateTime.parse(map['lastUpdated']),
      currentStreak: map['currentStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      lastLogDate:
          map['lastLogDate'] != null ? DateTime.parse(map['lastLogDate']) : null,
      dateOfBirth: parseDob(map['dateOfBirth']),
      abhaId: map['abhaId'],
    );
  }

  UserProfile copyWith({
    String? userId,
    String? name,
    String? selectedCondition,
    DateTime? createdAt,
    DateTime? lastUpdated,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastLogDate,
    DateTime? dateOfBirth,
    String? abhaId,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      selectedCondition: selectedCondition ?? this.selectedCondition,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLogDate: lastLogDate ?? this.lastLogDate,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      abhaId: abhaId ?? this.abhaId,
    );
  }
}
