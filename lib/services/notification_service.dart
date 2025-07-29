// lib/services/notification_service.dart
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:myapp/services/database_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/task.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._();

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing Awesome Notifications...');

      await AwesomeNotifications().initialize('resource://drawable/app_icon', [
        NotificationChannel(
          channelKey: 'task_reminders',
          channelName: 'Task Reminders',
          channelDescription: 'Daily task completion reminders',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelKey: 'due_time_alerts',
          channelName: 'Due Time Alerts',
          channelDescription:
              'Notifications for tasks approaching their due time',
          defaultColor: Colors.orange,
          ledColor: Colors.orange,
          importance: NotificationImportance.Max,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'overdue_alerts',
          channelName: 'Overdue Alerts',
          channelDescription: 'Notifications for overdue tasks',
          defaultColor: Colors.red,
          ledColor: Colors.red,
          importance: NotificationImportance.Max,
          playSound: true,
          enableVibration: true,
        ),
      ]);

      debugPrint('✅ Awesome Notifications initialized');

      // Request permissions
      await _requestPermissions();
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
      _isInitialized = false;
    }
  }

  static Future<void> _requestPermissions() async {
    debugPrint('🔑 Requesting notification permissions...');

    try {
      // Request basic notification permission
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
      debugPrint('✅ Notification permissions already granted');

      // Request exact alarm permission for precise scheduling
      final exactAlarmPermission =
          await Permission.scheduleExactAlarm.request();
      debugPrint('⏰ Exact alarm permission: ${exactAlarmPermission.isGranted}');
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }

    debugPrint('✅ Notification permissions requested');
  }

  // Safe method to schedule notifications with null checks
  static Future<void> scheduleAllTaskNotifications(Task task) async {
    if (!_isInitialized) {
      debugPrint(
        '⚠️ NotificationService not initialized, skipping notification scheduling',
      );
      return;
    }

    try {
      debugPrint('🔄 Scheduling all notifications for: ${task.title}');

      // Cancel existing notifications first
      await cancelTaskNotifications(task.id);

      if (!task.hasDueTime || task.isCompleted) {
        debugPrint('⏰ Due time is in the past, skipping: ${task.title}');
        return;
      }

      // Schedule due time notifications
      await _scheduleTaskDueNotification(task);
      await _scheduleOverdueNotification(task);

      debugPrint('✅ All notifications scheduled for: ${task.title}');
    } catch (e) {
      debugPrint('❌ Error scheduling notifications: $e');
    }
  }

  // Private method to schedule due time notification
  static Future<void> _scheduleTaskDueNotification(Task task) async {
    if (!task.hasDueTime || task.isCompleted) return;

    final dueTime = task.dueTime!;
    final now = DateTime.now();

    debugPrint(
      '📅 Scheduling notifications for task: ${task.title} at $dueTime',
    );

    // Don't schedule if due time is in the past
    if (dueTime.isBefore(now)) {
      debugPrint('⏰ Due time is in the past, skipping: ${task.title}');
      return;
    }

    try {
      // Schedule notification 30 minutes before due time
      final reminderTime = dueTime.subtract(const Duration(minutes: 30));
      if (reminderTime.isAfter(now)) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: _generateNotificationId(task.id, 0),
            channelKey: 'due_time_alerts',
            title: '⏰ Task Due Soon',
            body: '${task.title} is due in 30 minutes',
            icon: 'resource://drawable/notification_icon',
            bigPicture: 'resource://drawable/app_icon',
            notificationLayout: NotificationLayout.BigPicture,
            payload: {'task_id': task.id, 'type': 'due_soon'},
          ),
          schedule: NotificationCalendar.fromDate(date: reminderTime),
        );
        debugPrint('✅ Scheduled 30min reminder for: ${task.title}');
      }

      // Schedule notification at exact due time
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateNotificationId(task.id, 1),
          channelKey: 'due_time_alerts',
          title: '🚨 Task Due Now',
          body: '${task.title} is due now!',
          icon: 'resource://drawable/notification_icon',
          bigPicture: 'resource://drawable/app_icon',
          notificationLayout: NotificationLayout.BigPicture,
          payload: {'task_id': task.id, 'type': 'due_now'},
        ),
        schedule: NotificationCalendar.fromDate(date: dueTime),
      );
      debugPrint('✅ Scheduled exact due notification for: ${task.title}');
    } catch (e) {
      debugPrint('❌ Error scheduling due time notification: $e');
    }
  }

  // Private method to schedule overdue notification
  static Future<void> _scheduleOverdueNotification(Task task) async {
    if (!task.hasDueTime || task.isCompleted) return;

    final overdueTime = task.dueTime!.add(const Duration(hours: 1));
    final now = DateTime.now();

    // Don't schedule if overdue time is in the past
    if (overdueTime.isBefore(now)) return;

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateNotificationId(task.id, 2),
          channelKey: 'overdue_alerts',
          title: '❌ Task Overdue',
          body: '${task.title} is now overdue!',
          icon: 'resource://drawable/notification_icon',
          bigPicture: 'resource://drawable/app_icon',
          notificationLayout: NotificationLayout.BigPicture,
          payload: {'task_id': task.id, 'type': 'overdue'},
        ),
        schedule: NotificationCalendar.fromDate(date: overdueTime),
      );
      debugPrint('✅ Scheduled overdue notification for: ${task.title}');
    } catch (e) {
      debugPrint('❌ Error scheduling overdue notification: $e');
    }
  }

  // Generate safe notification ID from task ID
  static int _generateNotificationId(String taskId, int offset) {
    // Convert task ID to a numeric ID safely
    final hash = taskId.hashCode.abs();
    final baseId = hash % 1000000; // Ensure it's within reasonable range
    return baseId + offset;
  }

  // Cancel notifications for a specific task
  static Future<void> cancelTaskNotifications(String taskId) async {
    if (!_isInitialized) return;

    try {
      final baseId = _generateNotificationId(taskId, 0);

      // Cancel all related notifications (due soon, due now, overdue)
      await AwesomeNotifications().cancel(baseId);
      await AwesomeNotifications().cancel(baseId + 1);
      await AwesomeNotifications().cancel(baseId + 2);

      debugPrint('🚫 Cancelled notifications for task: $taskId');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  // Check and send notifications for tasks that are due/overdue right now
  static Future<void> checkAndSendImmediateNotifications() async {
    if (!_isInitialized) return;

    try {
      debugPrint('🔍 Checking for immediate notifications...');

      final now = DateTime.now();
      final todayTasks = await DatabaseService.getLocalTasks(date: now);

      int sentCount = 0;
      for (final task in todayTasks) {
        if (task.isCompleted || !task.hasDueTime) continue;

        final dueTime = task.dueTime!;
        final timeDiff = dueTime.difference(now);

        // Send immediate notification if task is overdue
        if (timeDiff.isNegative) {
          await _sendImmediateNotification(
            task: task,
            title: '❌ Task Overdue',
            body: '${task.title} is overdue!',
            type: 'immediate_overdue',
          );
          sentCount++;
        }
      }

      debugPrint('📱 Sent $sentCount immediate notifications');
    } catch (e) {
      debugPrint('❌ Error checking immediate notifications: $e');
    }
  }

  static Future<void> _sendImmediateNotification({
    required Task task,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey:
              type.contains('overdue') ? 'overdue_alerts' : 'due_time_alerts',
          title: title,
          body: body,
          icon: 'resource://drawable/notification_icon',
          bigPicture: 'resource://drawable/app_icon',
          notificationLayout: NotificationLayout.BigPicture,
          payload: {'task_id': task.id, 'type': type},
        ),
      );
      debugPrint('📤 Sent immediate notification: $title');
    } catch (e) {
      debugPrint('❌ Error sending immediate notification: $e');
    }
  }

  // Schedule daily reminder at 10 PM
  static Future<void> scheduleDailyReminder() async {
    if (!_isInitialized) return;

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'task_reminders',
          title: '📝 Daily Task Check',
          icon: 'resource://drawable/notification_icon',
          body: 'Don\'t forget to complete your tasks for today!',
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar(
          hour: 22, // 10 PM
          minute: 0,
          second: 0,
          repeats: true,
        ),
      );
      debugPrint('📅 Daily reminder scheduled for 10 PM');
    } catch (e) {
      debugPrint('❌ Error scheduling daily reminder: $e');
    }
  }

  // Reschedule all notifications for existing tasks
  static Future<void> rescheduleAllNotifications() async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized, skipping reschedule');
      return;
    }

    try {
      debugPrint('🔄 Rescheduling all notifications...');

      // Cancel all existing notifications first
      await AwesomeNotifications().cancelAll();
      debugPrint('🚫 Cancelled all notifications');

      // Get all incomplete tasks with due times
      final allTasks = await DatabaseService.getLocalTasks();
      final tasksWithDueTimes =
          allTasks
              .where((task) => task.hasDueTime && !task.isCompleted)
              .toList();

      debugPrint(
        '🔄 Rescheduling notifications for ${tasksWithDueTimes.length} tasks',
      );

      // Schedule notifications for each task
      for (final task in tasksWithDueTimes) {
        await scheduleAllTaskNotifications(task);
      }

      // Reschedule daily reminder
      await scheduleDailyReminder();

      debugPrint('✅ All notifications rescheduled successfully');
    } catch (e) {
      debugPrint('❌ Error rescheduling notifications: $e');
    }
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    if (!_isInitialized) return;

    try {
      await AwesomeNotifications().cancelAll();
      debugPrint('🚫 All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) return false;

    try {
      return await AwesomeNotifications().isNotificationAllowed();
    } catch (e) {
      debugPrint('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  // Open notification settings
  static Future<void> openNotificationSettings() async {
    if (!_isInitialized) return;

    try {
      await AwesomeNotifications().showNotificationConfigPage();
    } catch (e) {
      debugPrint('❌ Error opening notification settings: $e');
    }
  }

  // Static method for handling background actions (required by AwesomeNotifications)
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('📱 Notification action received: ${receivedAction.payload}');
    // Handle notification actions here
  }

  // Static method for handling notification creation (required by AwesomeNotifications)
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('📢 Notification created: ${receivedNotification.title}');
  }

  // Static method for handling notification display (required by AwesomeNotifications)
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('📱 Notification displayed: ${receivedNotification.title}');
  }
}
