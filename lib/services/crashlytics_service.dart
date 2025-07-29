import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CrashlyticsService {
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Initialize Crashlytics
  static Future<void> initialize() async {
    try {
      // Enable collection of crash reports
      await _crashlytics.setCrashlyticsCollectionEnabled(true);

      // Set up automatic crash reporting for Flutter errors
      FlutterError.onError = (FlutterErrorDetails details) {
        _crashlytics.recordFlutterFatalError(details);
        debugPrint('🔥 Flutter Fatal Error recorded: ${details.exception}');
      };

      // Catch errors that occur outside of the Flutter framework
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics.recordError(error, stack, fatal: true);
        debugPrint('🔥 Platform Error recorded: $error');
        return true;
      };

      debugPrint('✅ Crashlytics initialized successfully');
    } catch (e) {
      debugPrint('❌ Crashlytics initialization error: $e');
    }
  }

  /// Set user information for crash reports
  static Future<void> setUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _crashlytics.setUserIdentifier(user.uid);

        // Set additional user properties
        await _crashlytics.setCustomKey('user_email', user.email ?? 'unknown');
        await _crashlytics.setCustomKey(
          'display_name',
          user.displayName ?? 'unknown',
        );
        await _crashlytics.setCustomKey('email_verified', user.emailVerified);

        debugPrint('✅ Crashlytics user info set for: ${user.email}');
      } else {
        // Clear user info when signed out
        await _crashlytics.setUserIdentifier('anonymous');
        await _crashlytics.setCustomKey('user_email', 'anonymous');
        debugPrint('✅ Crashlytics user info cleared (anonymous)');
      }
    } catch (e) {
      debugPrint('❌ Error setting Crashlytics user info: $e');
    }
  }

  /// Log custom events and breadcrumbs
  static Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
      debugPrint('📝 Crashlytics log: $message');
    } catch (e) {
      debugPrint('❌ Error logging to Crashlytics: $e');
    }
  }

  /// Record custom non-fatal errors
  static Future<void> recordError({
    required dynamic exception,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
      debugPrint('🔥 Custom error recorded: $exception');
    } catch (e) {
      debugPrint('❌ Error recording custom error: $e');
    }
  }

  /// Set custom keys for better crash analysis
  static Future<void> setCustomKey(String key, dynamic value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
      debugPrint('🔑 Custom key set: $key = $value');
    } catch (e) {
      debugPrint('❌ Error setting custom key: $e');
    }
  }

  /// Record task-related operations for debugging
  static Future<void> recordTaskOperation(
    String operation, {
    String? taskId,
    String? taskTitle,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await log('Task Operation: $operation');

      if (taskId != null) {
        await setCustomKey('last_task_id', taskId);
      }
      if (taskTitle != null) {
        await setCustomKey('last_task_title', taskTitle);
      }

      // Record additional data as custom keys
      if (additionalData != null) {
        for (final entry in additionalData.entries) {
          await setCustomKey('task_${entry.key}', entry.value);
        }
      }

      await setCustomKey('last_operation', operation);
      await setCustomKey(
        'last_operation_time',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('❌ Error recording task operation: $e');
    }
  }

  /// Record authentication events
  static Future<void> recordAuthEvent(
    String event, {
    String? method,
    bool success = true,
  }) async {
    try {
      await log('Auth Event: $event - ${success ? 'Success' : 'Failed'}');
      await setCustomKey('last_auth_event', event);
      await setCustomKey('last_auth_method', method ?? 'unknown');
      await setCustomKey('last_auth_success', success);
      await setCustomKey('last_auth_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Error recording auth event: $e');
    }
  }

  /// Record sync operations
  static Future<void> recordSyncEvent(
    String event, {
    int? taskCount,
    bool success = true,
    String? error,
  }) async {
    try {
      await log('Sync Event: $event - ${success ? 'Success' : 'Failed'}');
      await setCustomKey('last_sync_event', event);
      await setCustomKey('last_sync_success', success);
      await setCustomKey('last_sync_time', DateTime.now().toIso8601String());

      if (taskCount != null) {
        await setCustomKey('last_sync_task_count', taskCount);
      }

      if (error != null) {
        await setCustomKey('last_sync_error', error);
      }
    } catch (e) {
      debugPrint('❌ Error recording sync event: $e');
    }
  }

  /// Record notification events
  static Future<void> recordNotificationEvent(
    String event, {
    String? taskId,
    String? notificationType,
  }) async {
    try {
      await log('Notification Event: $event');
      await setCustomKey('last_notification_event', event);
      await setCustomKey(
        'last_notification_time',
        DateTime.now().toIso8601String(),
      );

      if (taskId != null) {
        await setCustomKey('last_notification_task_id', taskId);
      }

      if (notificationType != null) {
        await setCustomKey('last_notification_type', notificationType);
      }
    } catch (e) {
      debugPrint('❌ Error recording notification event: $e');
    }
  }

  /// Force a test crash (for testing purposes only)
  static void testCrash() {
    if (kDebugMode) {
      debugPrint('🧪 Testing Crashlytics - This will cause a crash!');
      _crashlytics.crash();
    } else {
      debugPrint('⚠️ Test crash is only available in debug mode');
    }
  }

  /// Check if Crashlytics is enabled
  static Future<bool> isCrashlyticsCollectionEnabled() async {
    try {
      return await _crashlytics.isCrashlyticsCollectionEnabled;
    } catch (e) {
      debugPrint('❌ Error checking Crashlytics status: $e');
      return false;
    }
  }

  /// Enable/disable Crashlytics collection
  static Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
      debugPrint(
        '✅ Crashlytics collection ${enabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('❌ Error setting Crashlytics collection: $e');
    }
  }
}
