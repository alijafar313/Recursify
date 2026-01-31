import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import '../data/app_database.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  static const String channelId = 'moodly_reminders';
  static const String channelName = 'Mood Reminders';
  static const String channelDescription = 'Reminders to log your mood';

  /// Initialize the plugin
  Future<void> init() async {
    tz_data.initializeTimeZones();

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    const fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const fln.InitializationSettings initializationSettings = fln.InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (fln.NotificationResponse response) async {
        if (response.input?.isNotEmpty ?? false) {
          // This is a "Reply" action
          await _handleDirectReply(response.input!);
        }
      },
    );

    // Auto-cleanup Old Trash
    try {
      await AppDatabase.cleanupTrash();
    } catch (_) {
      // ignore
    }
  }

  /// Request permissions (Android 13+ and iOS)
  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
        
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            fln.IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Schedule notifications based on settings
  Future<void> scheduleNotifications({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required Duration interval,
  }) async {
    // 1. Cancel all existing
    await flutterLocalNotificationsPlugin.cancelAll();

    // 2. Calculate slots
    final now = DateTime.now();
    var currentSlot = DateTime(
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );

    final endSlot = DateTime(
      now.year,
      now.month,
      now.day,
      endTime.hour,
      endTime.minute,
    );
    
    int id = 0;
    while (currentSlot.isBefore(endSlot) || currentSlot.isAtSameMomentAs(endSlot)) {
      await _scheduleDaily(currentSlot.hour, currentSlot.minute, id++);
      currentSlot = currentSlot.add(interval);
    }
  }

  Future<void> _scheduleDaily(int hour, int minute, int id) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'How are you feeling?',
      'Tap Quick Log to select mood (-5 to 5)',
      _nextInstanceOf(hour, minute),
      fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          actions: [
            fln.AndroidNotificationAction(
              'quick_log',
              'Quick Log',
              inputs: [
                fln.AndroidNotificationActionInput(
                  label: 'Select or Type (-5 to 5)',
                  choices: const [
                     '-5', '-4', '-3', '-2', '-1', '0', '1', '2', '3', '4', '5'
                  ],
                  allowFreeFormInput: true,
                ),
              ],
            ),
          ],
        ),
        iOS: const fln.DarwinNotificationDetails(
          categoryIdentifier: 'mood_category',
        ),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: fln.DateTimeComponents.time, // Recurring daily
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> triggerNotification({required String title, required String body}) async {
    await flutterLocalNotificationsPlugin.show(
      99999, // Specific ID for test
      title,
      body,
      fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: fln.Importance.max,
          priority: fln.Priority.high,
           actions: [
            fln.AndroidNotificationAction(
              'quick_log',
              'Quick Log',
              inputs: [
                fln.AndroidNotificationActionInput(
                  label: 'Select or Type (-5 to 5)',
                  choices: const [
                    '-5', '-4', '-3', '-2', '-1', '0', '1', '2', '3', '4', '5'
                  ],
                  allowFreeFormInput: true, 
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDirectReply(String input) async {
    // Parse input (-5 to 5)
    final intensity = int.tryParse(input.trim());
    if (intensity != null && intensity >= -5 && intensity <= 5) {
      await AppDatabase.insertSnapshot(
        title: 'Quick Log', // Default context for quick replies
        intensity: intensity,
        note: 'Via Notification',
      );
      print("Quick Log saved: $intensity");
      
      // Update the notification to show success and stop spinner
      await flutterLocalNotificationsPlugin.show(
        99999, // Use the same ID to overwrite (for test notification)
        'Mood Logged',
        'Saved mood intensity: $intensity',
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: fln.Importance.max,
            priority: fln.Priority.high,
            timeoutAfter: 3000, // Auto dismiss after 3s
          ),
        ),
      );
      
    } else {
      print("Invalid input: $input");
    }
  }
}
