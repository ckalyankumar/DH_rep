/// A report document stored at Firestore path: users/{userId}/reports.
class UserReport {
  final String id;
  final DateTime createdAt;
  final String? period; // e.g. '7days', '30days', '90days', 'all'
  final Map<String, dynamic>? summary; // flexible summary data

  UserReport({
    required this.id,
    required this.createdAt,
    this.period,
    this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      if (period != null) 'period': period,
      if (summary != null) 'summary': summary,
    };
  }

  static UserReport fromJson(Map<String, dynamic> json, {String? id}) {
    return UserReport(
      id: id ?? json['id'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      period: json['period'] as String?,
      summary: json['summary'] != null
          ? Map<String, dynamic>.from(json['summary'] as Map)
          : null,
    );
  }
}
