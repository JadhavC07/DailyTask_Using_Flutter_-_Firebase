import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:myapp/services/database_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/task.dart';

class NotificationService {
  static Future<void> initialize() async {
    await AwesomeNotifications().initialize('resource://drawable/app_icon', [
      NotificationChannel(
        channelKey: 'task_reminders',
        channelName: 'Task Reminders',
        channelDescription: 'Daily task completion reminders',
        defaultColor: Colors.blue,
        ledColor: Colors.blue,
        importance: NotificationImportance.High,
      ),
    ]);

    // Request permissions
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    await Permission.notification.request();
    await AwesomeNotifications().isNotificationAllowed().then((
      isAllowed,
    ) async {
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  // Schedule daily reminder at 10 PM
  static Future<void> scheduleDailyReminder() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'task_reminders',
        title: '📝 Daily Task Check',
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
  }

  // Send immediate notification for incomplete tasks
  static Future<void> sendIncompleteTasksReminder(
    List<Task> incompleteTasks,
  ) async {
    if (incompleteTasks.isEmpty) return;

    String body =
        incompleteTasks.length == 1
            ? 'You have 1 incomplete task: ${incompleteTasks.first.title}'
            : 'You have ${incompleteTasks.length} incomplete tasks today';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'task_reminders',
        title: '⚠️ Incomplete Tasks',
        body: body,
        notificationLayout: NotificationLayout.BigText,
      ),
    );
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  // Add to notification_service.dart
  static Future<void> checkAndSendIncompleteReminder() async {
    final now = DateTime.now();

    // Only send reminder at 10 PM
    if (now.hour != 22) return;

    try {
      final todayTasks = await DatabaseService.getLocalTasks(
        date: DateTime.now(),
      );

      final incompleteTasks =
          todayTasks.where((task) => !task.isCompleted).toList();

      if (incompleteTasks.isNotEmpty) {
        await sendIncompleteTasksReminder(incompleteTasks);
      }
    } catch (e) {
      print('Error checking incomplete tasks: $e');
    }
  }
}
