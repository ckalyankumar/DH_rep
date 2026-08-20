import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';

class LogStorageService {
  static const String _logsKey = 'dhealth_daily_logs';
  static const String _streakKey = 'dhealth_streak';
  static const String _lastLogDateKey = 'dhealth_last_log_date';
  
  // Save a new daily log
  Future<void> saveLog(DailyLog log) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing logs
    final logs = await getLogs();
    
    // Add new log at the beginning
    logs.insert(0, log);
    
    // Keep only last 90 days
    if (logs.length > 90) {
      logs.removeRange(90, logs.length);
    }
    
    // Convert to JSON and save
    final jsonLogs = logs.map((log) => log.toJson()).toList();
    await prefs.setString(_logsKey, jsonEncode(jsonLogs));
    
    // Update last log date
    await prefs.setString(_lastLogDateKey, log.date.toIso8601String());
    
    // Update streak
    await updateStreak();
  }
  
  // Get all logs (sorted by date, newest first)
  Future<List<DailyLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString(_logsKey);
    
    if (logsJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(logsJson);
    return decoded.map((json) => DailyLog.fromJson(json as Map<String, dynamic>)).toList();
  }
  
  // Get logs for specific date range
  Future<List<DailyLog>> getLogsInRange(DateTime start, DateTime end) async {
    final logs = await getLogs();
    return logs.where((log) {
      return log.date.isAfter(start.subtract(const Duration(days: 1))) &&
             log.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }
  
  // Get today's log (if exists)
  Future<DailyLog?> getTodayLog() async {
    final logs = await getLogs();
    final today = DateTime.now();
    
    try {
      return logs.firstWhere(
        (log) => log.date.year == today.year &&
                 log.date.month == today.month &&
                 log.date.day == today.day,
      );
    } catch (e) {
      return null;
    }
  }
  
  // Calculate and update streak
  Future<int> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    
    if (logs.isEmpty) {
      await prefs.setInt(_streakKey, 0);
      return 0;
    }
    
    // Sort logs by date (newest first)
    logs.sort((a, b) => b.date.compareTo(a.date));
    
    int streak = 1;
    DateTime lastDate = logs[0].date;
    
    for (int i = 1; i < logs.length; i++) {
      final diff = lastDate.difference(logs[i].date).inDays;
      
      if (diff == 1) {
        // Consecutive day
        streak++;
        lastDate = logs[i].date;
      } else {
        // Streak broken
        break;
      }
    }
    
    await prefs.setInt(_streakKey, streak);
    return streak;
  }
  
  // Get current streak
  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }
  
  // Get logs for a specific condition
  Future<List<DailyLog>> getLogsByCondition(String conditionId) async {
    final logs = await getLogs();
    return logs.where((log) => log.condition == conditionId).toList();
  }
  
  // Calculate average metrics for last N days
  Future<Map<String, double>> getAverageMetrics(int days) async {
    final logs = await getLogs();
    final recentLogs = logs.take(days).toList();
    
    if (recentLogs.isEmpty) {
      return {
        'avgMood': 3.0,
        'avgItch': 5.0,
        'avgStress': 5.0,
        'avgSleep': 3.0,
      };
    }
    
    return {
      'avgMood': recentLogs.map((l) => l.mood.toDouble()).reduce((a, b) => a + b) / recentLogs.length,
      'avgItch': recentLogs.map((l) => l.itchIntensity.toDouble()).reduce((a, b) => a + b) / recentLogs.length,
      'avgStress': recentLogs.map((l) => l.stressLevel.toDouble()).reduce((a, b) => a + b) / recentLogs.length,
      'avgSleep': recentLogs.map((l) => l.sleepQuality.toDouble()).reduce((a, b) => a + b) / recentLogs.length,
    };
  }
  
  // Check if today's log exists
  Future<bool> hasTodayLog() async {
    final log = await getTodayLog();
    return log != null;
  }
  
  // Clear all logs (for testing)
  Future<void> clearAllLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logsKey);
    await prefs.remove(_streakKey);
    await prefs.remove(_lastLogDateKey);
  }
}
