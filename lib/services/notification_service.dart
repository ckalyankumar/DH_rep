import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';

/// Service for scheduling local notifications.
class NotificationService {
  /// Pending payload from notification tap (for deep linking when app launches from cold start).
  static String? _pendingPayload;

  /// Called when a notification payload is received (tap or cold launch).
  static void Function()? onPayloadReceived;

  /// Returns and clears the pending notification payload, if any.
  static String? consumePendingPayload() {
    final p = _pendingPayload;
    _pendingPayload = null;
    return p;
  }
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Payloads used for deep linking.
  static const String payloadDaily = 'daily';
  static const String payloadWeeklyPro = 'weekly_pro';

  /// Call once from main() before runApp(). Only on mobile (skips web).
  static Future<void> initialize({
    void Function(NotificationResponse)? onNotificationTapped,
  }) async {
    if (kIsWeb) return;
    try {
      await _initializeTimezone();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      final initSettings = const InitializationSettings(
        android: android,
        iOS: ios,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _pendingPayload = payload;
            onPayloadReceived?.call();
            onNotificationTapped?.call(response);
          }
        },
      );

      // Handle app launch from notification (cold start).
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final response = launchDetails?.notificationResponse;
        final payload = response?.payload;
        if (payload != null && payload.isNotEmpty) {
          _pendingPayload = payload;
        }
      }

      await _requestPermissionsIfNeeded();
    } catch (e) {
      debugPrint('NotificationService.initialize failed: $e');
    }
  }

  static Future<void> _initializeTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static Future<void> _requestPermissionsIfNeeded() async {
    try {
      if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (status.isDenied) {
          await Permission.notification.request();
        }
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Schedules a repeating daily notification at [hour]:[minute].
  /// Cancels any existing daily reminder before scheduling.
  /// Notification ID: 1. Payload: [payloadDaily] for deep link to check-in.
  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(1);
      final scheduledTime = _nextInstanceOf(hour, minute);
      await _plugin.zonedSchedule(
        1,
        'How is your skin today?',
        'Tap to log your daily check-in.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Daily Check-in Reminder',
            channelDescription: 'Daily reminder to log your skin health',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payloadDaily,
      );
    } catch (e) {
      debugPrint('scheduleDailyReminder failed: $e');
    }
  }

  /// Schedules a weekly notification for the PRO questionnaire.
  /// Fires every Sunday at 10:00 AM. Notification ID: 2.
  /// Payload: [payloadWeeklyPro] for deep link to questionnaire.
  static Future<void> scheduleWeeklyProReminder() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(2);
      final next = _nextSunday(10, 0);
      await _plugin.zonedSchedule(
        2,
        'Weekly skin check — 2 minutes',
        'Your weekly questionnaire is ready. How has your skin been?',
        next,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_pro',
            'Weekly Questionnaire Reminder',
            channelDescription:
                'Weekly reminder to complete your POEM or DLQI questionnaire',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payloadWeeklyPro,
      );
    } catch (e) {
      debugPrint('scheduleWeeklyProReminder failed: $e');
    }
  }

  /// Cancels the weekly PRO reminder (ID: 2).
  static Future<void> cancelWeeklyProReminder() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(2);
    } catch (e) {
      debugPrint('cancelWeeklyProReminder failed: $e');
    }
  }

  /// Cancels all notifications.
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextSunday(int hour, int minute) {
    var dt = tz.TZDateTime.now(tz.local);
    while (dt.weekday != DateTime.sunday) {
      dt = dt.add(const Duration(days: 1));
    }
    return tz.TZDateTime(tz.local, dt.year, dt.month, dt.day, hour, minute);
  }
}
