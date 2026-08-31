import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
/// Saves user profile to Firestore at users/{uid}/profile.
abstract class FirestoreUserProfileService {
  /// Updates role at users/{uid} (profile.role field). Merges with existing data.
  /// Expected values: 'patient' | 'doctor'.
  static Future<void> saveRole(String uid, String role) async {
    final normalized = role.trim().toLowerCase();
    if (normalized != 'doctor' && normalized != 'patient') return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'profile': {'role': normalized},
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Updates condition at users/{uid} (profile.condition field). Merges with existing data.
  static Future<void> saveCondition(String uid, String condition) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'profile.condition': condition,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Updates date of birth at users/{uid} (profile.dateOfBirth field).
  /// Nullable; when null, the field is explicitly set to null.
  static Future<void> saveDateOfBirth(String uid, DateTime? dob) async {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final String? dobString =
        dob != null ? dateFormatter.format(dob) : null;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'profile.dateOfBirth': dobString,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Updates ABHA ID at users/{uid} (profile.abhaId field).
  /// Nullable; when null, the field is explicitly set to null.
  static Future<void> saveAbhaId(String uid, String? abhaId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'profile.abhaId': abhaId,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Convenience wrapper for saving both demographics in one call.
  /// Used in onboarding where both values are captured together.
  static Future<void> saveDemographics(
    String uid, {
    DateTime? dateOfBirth,
    String? abhaId,
  }) async {
    await Future.wait([
      saveDateOfBirth(uid, dateOfBirth),
      saveAbhaId(uid, abhaId),
    ]);
  }

  /// Fetches the lightweight profile sub-document for the given user.
  /// Returns a map with keys like 'condition', 'dateOfBirth', 'abhaId' when present.
  static Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists) return null;
      final data = snap.data();
      final profile = data?['profile'];
      if (profile is Map<String, dynamic>) {
        return profile;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Returns normalized role from users/{uid}/profile.role.
  /// Defaults to 'patient' when missing/invalid/error.
  static Future<String> getRole(String uid) async {
    try {
      final profile = await getProfile(uid);
      final raw = profile?['role'];
      if (raw is String) {
        final role = raw.trim().toLowerCase();
        if (role == 'doctor' || role == 'patient') {
          return role;
        }
      }
      return 'patient';
    } catch (_) {
      return 'patient';
    }
  }
}