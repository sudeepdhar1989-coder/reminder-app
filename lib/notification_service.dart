import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart'; // ✅ iOS FIXED
import 'package:permission_handler/permission_handler.dart';
import 'reminder_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _reminderChannelId = 'reminder_channel_v2';
  static const String _reminderChannelName = 'Reminders';

  Future<bool> init() async {
    try {
      // ✅ iOS: Proper timezone setup
      tz.initializeTimeZones();
      final String? deviceTimeZone = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimeZone ?? 'UTC'));

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: false,
      );

      final bool? initialized = await _notifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          print('🔔 Notification tapped: ${response.payload}');
        },
      );

      await _createNotificationChannels();
      await requestPermissions();

      print('✅ NotificationService initialized: $initialized');
      return initialized == true;
    } catch (e, stack) {
      print('❌ Notification init error: $e\n$stack');
      return false;
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final reminderChannel = AndroidNotificationChannel(
      _reminderChannelId,
      _reminderChannelName,
      description: 'Reminder notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(reminderChannel);
  }

  Future<bool> requestPermissions() async {
    try {
      // ✅ iOS: Proper notification permission
      final notifStatus = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      
      // Fallback for Android
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
      
      print('🔔 Notification permission granted');
      return true;
    } catch (e) {
      print('❌ Permission error: $e');
      return false;
    }
  }

  Future<void> scheduleExactTimeReminder(Reminder reminder) async {
    if (!reminder.isActive || reminder.id == null) return;

    try {
      final scheduledDateTime = reminder.getExactReminderDateTime();
      final now = DateTime.now();

      if (scheduledDateTime.isBefore(now)) return;

      final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          channelDescription: 'Reminder notifications',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          ticker: '${_getTypeEmoji(reminder.type)} ${reminder.title}',
          styleInformation: BigTextStyleInformation(
            '${reminder.notes ?? ''}\n⏰ ${_formatTime(scheduledDateTime)}',
            contentTitle: '${_getTypeEmoji(reminder.type)} ${reminder.title}',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      await _notifications.zonedSchedule(
        reminder.id!,
        '${_getTypeEmoji(reminder.type)} ${reminder.title}',
        reminder.notes ?? 'Tap to view reminder',
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('✅ Scheduled: "${reminder.title}" at $scheduledDateTime');
    } catch (e) {
      print('❌ Schedule error: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  String _getTypeEmoji(String type) {
    switch (type) {
      case 'birthday': return '🎂';
      case 'anniversary': return '💕';
      case 'event': return '📅';
      case 'task': return '✅';
      default: return '🔔';
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}