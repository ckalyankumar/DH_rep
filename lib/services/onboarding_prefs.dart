import 'package:shared_preferences/shared_preferences.dart';

/// Persists onboarding state and user choices. Never blocks app on failure.
abstract class OnboardingPrefs {
  static const _keyComplete = 'onboarding_complete';
  static const _keyCondition = 'onboarding_condition';
  static const _keyReminderHour = 'reminder_hour';
  static const _keyReminderMinute = 'reminder_minute';
  static const _keyWeeklyProEnabled = 'weekly_pro_reminder_enabled';

  static const int _defaultReminderHour = 20; // 8 PM
  static const int _defaultReminderMinute = 0;

  /// Returns true if onboarding is complete. On prefs error, returns true (show home).
  static Future<bool> isComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyComplete) ?? false;
    } catch (_) {
      return true; // Never block app; default to home
    }
  }

  static Future<void> setComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyComplete, true);
    } catch (_) {}
  }

  static Future<void> setCondition(String condition) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCondition, condition);
    } catch (_) {}
  }

  static Future<String> getCondition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyCondition) ?? 'psoriasis';
    } catch (_) {
      return 'psoriasis';
    }
  }

  static Future<void> setReminderTime(int hour, int minute) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyReminderHour, hour);
      await prefs.setInt(_keyReminderMinute, minute);
    } catch (_) {}
  }

  static Future<({int hour, int minute})> getReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        hour: prefs.getInt(_keyReminderHour) ?? _defaultReminderHour,
        minute: prefs.getInt(_keyReminderMinute) ?? _defaultReminderMinute,
      );
    } catch (_) {
      return (hour: _defaultReminderHour, minute: _defaultReminderMinute);
    }
  }

  static int get defaultReminderHour => _defaultReminderHour;
  static int get defaultReminderMinute => _defaultReminderMinute;

  /// Whether the weekly PRO questionnaire reminder is enabled. Default true.
  static Future<bool> getWeeklyProReminderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyWeeklyProEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setWeeklyProReminderEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWeeklyProEnabled, enabled);
    } catch (_) {}
  }
}
