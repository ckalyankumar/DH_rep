import 'package:shared_preferences/shared_preferences.dart';

/// Persists uid for background wearable sync. Set at login, read by callback.
class WearableSyncPrefs {
  static const _uidKey = 'dhealth_wearable_sync_uid';

  static Future<void> setUid(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, uid);
  }

  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_uidKey);
  }

  static Future<void> clearUid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
  }
}
