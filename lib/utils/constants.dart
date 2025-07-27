class AppConstants {
  // Notification IDs
  static const int dailyReminderId = 1;
  static const int incompleteTasksId = 2;

  // Shared Preferences Keys
  static const String offlineModeKey = 'offline_mode';
  static const String lastSyncKey = 'last_sync';
  static const String notificationsEnabledKey = 'notifications_enabled';

  // App Settings
  static const int reminderHour = 22; // 10 PM
  static const int reminderMinute = 0;
  static const Duration syncInterval = Duration(minutes: 5);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardElevation = 2.0;
  static const double borderRadius = 8.0;
}

// Date helpers
class DateHelpers {
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static bool isTomorrow(DateTime date) {
    return isSameDay(date, DateTime.now().add(const Duration(days: 1)));
  }

  static String getRelativeDateString(DateTime date) {
    if (isToday(date)) return 'Today';
    if (isTomorrow(date)) return 'Tomorrow';

    final difference = date.difference(DateTime.now()).inDays;
    if (difference > 0 && difference <= 7) {
      return 'In $difference days';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}
