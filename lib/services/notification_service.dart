// lib/services/notification_service.dart
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

  // Schedule notification for a task's due time
  static Future<void> scheduleTaskDueNotification(Task task) async {
    if (!task.hasDueTime || task.isCompleted) return;

    final dueTime = task.dueTime!;
    final now = DateTime.now();

    // Don't schedule if due time is in the past
    if (dueTime.isBefore(now)) return;

    // Schedule notification 30 minutes before due time
    final reminderTime = dueTime.subtract(const Duration(minutes: 30));
    if (reminderTime.isAfter(now)) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: int.parse(
            task.id
                .replaceAll(RegExp(r'[^0-9]'), '')
                .padLeft(9, '0')
                .substring(0, 9),
          ),
          channelKey: 'due_time_alerts',
          title: '⏰ Task Due Soon',
          body: '${task.title} is due in 30 minutes',
          bigPicture: 'resource://drawable/app_icon',
          notificationLayout: NotificationLayout.BigPicture,
          payload: {'task_id': task.id, 'type': 'due_soon'},
        ),
        schedule: NotificationCalendar.fromDate(date: reminderTime),
      );
    }

    // Schedule notification at exact due time
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id:
            int.parse(
              task.id
                  .replaceAll(RegExp(r'[^0-9]'), '')
                  .padLeft(9, '0')
                  .substring(0, 9),
            ) +
            1,
        channelKey: 'due_time_alerts',
        title: '🚨 Task Due Now',
        body: '${task.title} is due now!',
        bigPicture: 'resource://drawable/app_icon',
        notificationLayout: NotificationLayout.BigPicture,
        payload: {'task_id': task.id, 'type': 'due_now'},
      ),
      schedule: NotificationCalendar.fromDate(date: dueTime),
    );

    debugPrint('📅 Scheduled notifications for task: ${task.title}');
  }

  // Schedule overdue notification (1 hour after due time)
  static Future<void> scheduleOverdueNotification(Task task) async {
    if (!task.hasDueTime || task.isCompleted) return;

    final overdueTime = task.dueTime!.add(const Duration(hours: 1));
    final now = DateTime.now();

    // Don't schedule if overdue time is in the past
    if (overdueTime.isBefore(now)) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id:
            int.parse(
              task.id
                  .replaceAll(RegExp(r'[^0-9]'), '')
                  .padLeft(9, '0')
                  .substring(0, 9),
            ) +
            2,
        channelKey: 'overdue_alerts',
        title: '❌ Task Overdue',
        body: '${task.title} is now overdue!',
        bigPicture: 'resource://drawable/app_icon',
        notificationLayout: NotificationLayout.BigPicture,
        payload: {'task_id': task.id, 'type': 'overdue'},
      ),
      schedule: NotificationCalendar.fromDate(date: overdueTime),
    );

    debugPrint('⏰ Scheduled overdue notification for task: ${task.title}');
  }

  // Cancel notifications for a specific task
  static Future<void> cancelTaskNotifications(String taskId) async {
    final baseId = int.parse(
      taskId.replaceAll(RegExp(r'[^0-9]'), '').padLeft(9, '0').substring(0, 9),
    );

    // Cancel all related notifications (due soon, due now, overdue)
    await AwesomeNotifications().cancel(baseId);
    await AwesomeNotifications().cancel(baseId + 1);
    await AwesomeNotifications().cancel(baseId + 2);

    debugPrint('🚫 Cancelled notifications for task: $taskId');
  }

  // Schedule all notifications when a task is created/updated
  static Future<void> scheduleAllTaskNotifications(Task task) async {
    // Cancel existing notifications first
    await cancelTaskNotifications(task.id);

    if (!task.hasDueTime || task.isCompleted) return;

    // Schedule due time notifications
    await scheduleTaskDueNotification(task);
    await scheduleOverdueNotification(task);
  }

  // Check and send notifications for tasks that are due/overdue right now
  static Future<void> checkAndSendImmediateNotifications() async {
    try {
      final now = DateTime.now();
      final todayTasks = await DatabaseService.getLocalTasks(date: now);

      for (final task in todayTasks) {
        if (task.isCompleted || !task.hasDueTime) continue;

        final dueTime = task.dueTime!;
        final timeDiff = dueTime.difference(now);

        // Send immediate notification if task is due within 5 minutes and not notified yet
        if (timeDiff.inMinutes <= 5 && timeDiff.inMinutes >= 0) {
          await _sendImmediateNotification(
            task: task,
            title: '🚨 Task Due Soon',
            body:
                '${task.title} is due in ${timeDiff.inMinutes} minute${timeDiff.inMinutes != 1 ? 's' : ''}!',
            type: 'immediate_due_soon',
          );
        }
        // Send immediate notification if task is overdue
        else if (timeDiff.isNegative) {
          final overdueDuration = now.difference(dueTime);
          await _sendImmediateNotification(
            task: task,
            title: '❌ Task Overdue',
            body:
                '${task.title} is overdue by ${_formatDuration(overdueDuration)}',
            type: 'immediate_overdue',
          );
        }
      }
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
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey:
            type.contains('overdue') ? 'overdue_alerts' : 'due_time_alerts',
        title: title,
        body: body,
        bigPicture: 'resource://drawable/app_icon',
        notificationLayout: NotificationLayout.BigPicture,
        payload: {'task_id': task.id, 'type': type},
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays != 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours != 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes != 1 ? 's' : ''}';
    }
  }

  // Schedule daily reminder at 10 PM (existing functionality)
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

  // Check and send incomplete reminder (existing functionality)
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
      debugPrint('❌ Error checking incomplete tasks: $e');
    }
  }

  // Get all scheduled notifications (for debugging)
  static Future<List<NotificationModel>> getScheduledNotifications() async {
    return await AwesomeNotifications().listScheduledNotifications();
  }

  // Handle notification action when user taps on notification
  static Future<void> handleNotificationAction(
    ReceivedAction receivedAction,
  ) async {
    final payload = receivedAction.payload;
    if (payload == null) return;

    final taskId = payload['task_id'];
    final type = payload['type'];

    debugPrint('📱 Notification tapped - Task: $taskId, Type: $type');

    // You can add navigation logic here to open the app to the specific task
    // For example, navigate to home screen with the specific date selected
  }

  // Reschedule all notifications for existing tasks (useful after app restart)
  static Future<void> rescheduleAllNotifications() async {
    try {
      // Cancel all existing notifications first
      await cancelAllNotifications();

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

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  // Open notification settings
  static Future<void> openNotificationSettings() async {
    await AwesomeNotifications().showNotificationConfigPage();
  }
}
