import 'package:cloud_firestore/cloud_firestore.dart';

enum WearableProvider {
  fitbit,
  appleHealth,
  garmin,
  oura,
  samsungHealth,
  googleFit,
}

enum WearableScope {
  sleep,
  hrv,
  activity,
  heartRate,
  stress,
  readiness,
}

/// OAuth-linked wearable source. Stored at users/{uid}/wearableSources/{provider.name}
/// Note: encryptedOauthToken is stored encrypted; never log this field.
class WearableSource {
  final String id;
  final String uid;
  final WearableProvider provider;
  final List<WearableScope> scopes;
  final String encryptedOauthToken;
  final DateTime lastSyncedAt;
  final bool isActive;
  final DateTime consentGrantedAt;

  const WearableSource({
    required this.id,
    required this.uid,
    required this.provider,
    required this.scopes,
    required this.encryptedOauthToken,
    required this.lastSyncedAt,
    required this.isActive,
    required this.consentGrantedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'provider': provider.name,
      'scopes': scopes.map((s) => s.name).toList(),
      'encryptedOauthToken': encryptedOauthToken,
      'lastSyncedAt': lastSyncedAt.toIso8601String(),
      'isActive': isActive,
      'consentGrantedAt': consentGrantedAt.toIso8601String(),
    };
  }

  static WearableSource fromFirestore(
    Map<String, dynamic> data, {
    required String id,
  }) {
    return WearableSource(
      id: id,
      uid: data['uid'] as String? ?? '',
      provider: WearableProvider.values.byName(
        data['provider'] as String? ?? WearableProvider.fitbit.name,
      ),
      scopes: (data['scopes'] as List<dynamic>?)
              ?.map((e) => WearableScope.values.byName(e as String))
              .toList() ??
          [],
      encryptedOauthToken: data['encryptedOauthToken'] as String? ?? '',
      lastSyncedAt: _parseDateTime(data['lastSyncedAt']),
      isActive: data['isActive'] as bool? ?? true,
      consentGrantedAt: _parseDateTime(data['consentGrantedAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  WearableSource copyWith({
    String? id,
    String? uid,
    WearableProvider? provider,
    List<WearableScope>? scopes,
    String? encryptedOauthToken,
    DateTime? lastSyncedAt,
    bool? isActive,
    DateTime? consentGrantedAt,
  }) {
    return WearableSource(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      provider: provider ?? this.provider,
      scopes: scopes ?? this.scopes,
      encryptedOauthToken: encryptedOauthToken ?? this.encryptedOauthToken,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isActive: isActive ?? this.isActive,
      consentGrantedAt: consentGrantedAt ?? this.consentGrantedAt,
    );
  }
}
