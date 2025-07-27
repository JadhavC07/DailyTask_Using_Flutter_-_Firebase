import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import '../models/task.dart';
import 'package:flutter/material.dart';

class SyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static Timer? _debounceTimer;

  static void debouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      syncPendingTasks();
    });
  }

  // Start periodic sync every 5 minutes when online and authenticated
  static void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncPendingTasks();
    });
    debugPrint('🔄 Started periodic sync (every 5 minutes)');
  }

  static void stopSync() {
    _syncTimer?.cancel();
    debugPrint('⏹️ Stopped periodic sync');
  }

  // Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final List<ConnectivityResult> connectivityResult =
          await Connectivity().checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  // Sync all unsynced local tasks to cloud
  static Future<void> syncPendingTasks() async {
    if (_isSyncing) {
      debugPrint('⏸️ Sync already in progress, skipping...');
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('❌ Cannot sync: User not authenticated');
      return;
    }

    _isSyncing = true;

    try {
      // Check internet connectivity
      if (!await hasInternetConnection()) {
        debugPrint('❌ No internet connection, skipping sync');
        return;
      }

      // Get unsynced tasks from local database
      final db = await DatabaseService.database;
      List<Map<String, dynamic>> unsyncedMaps = [];

      try {
        unsyncedMaps = await db.query(
          'tasks',
          where: 'synced = ? OR synced IS NULL',
          whereArgs: [0],
        );
      } catch (e) {
        debugPrint('⚠️ Synced column not available, syncing all tasks');
        unsyncedMaps = await db.query('tasks');
      }

      final unsyncedTasks =
          unsyncedMaps.map((map) => Task.fromMap(map)).toList();

      if (unsyncedTasks.isEmpty) {
        debugPrint('✅ No tasks to sync');
        return;
      }

      debugPrint('🔄 Syncing ${unsyncedTasks.length} pending tasks...');

      // Sync each task
      for (final task in unsyncedTasks) {
        try {
          await DatabaseService.syncToCloud(task);
          await Future.delayed(
            const Duration(milliseconds: 100),
          ); // Rate limiting
        } catch (e) {
          debugPrint('❌ Failed to sync task ${task.title}: $e');
          // Continue with other tasks
        }
      }

      debugPrint('✅ Synced ${unsyncedTasks.length} tasks to cloud');
    } catch (e) {
      debugPrint('❌ Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Full bidirectional sync (merge local and cloud data)
  static Future<void> fullSync() async {
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('❌ Cannot perform full sync: User not authenticated');
      return;
    }

    if (!await hasInternetConnection()) {
      debugPrint('❌ Cannot perform full sync: No internet connection');
      return;
    }

    debugPrint('🔄 Starting full sync...');

    try {
      // Get all local tasks
      final localTasks = await DatabaseService.getLocalTasks();
      final localTaskIds = localTasks.map((t) => t.id).toSet();

      // Get all cloud tasks
      final cloudTasks = await DatabaseService.getCloudTasks();
      final cloudTaskIds = cloudTasks.map((t) => t.id).toSet();

      // Upload local tasks not in cloud
      int uploadCount = 0;
      for (final task in localTasks) {
        if (!cloudTaskIds.contains(task.id)) {
          try {
            await DatabaseService.syncToCloud(task);
            uploadCount++;
          } catch (e) {
            debugPrint('❌ Failed to upload task ${task.title}: $e');
          }
        }
      }

      // Download cloud tasks not in local
      int downloadCount = 0;
      for (final task in cloudTasks) {
        if (!localTaskIds.contains(task.id)) {
          try {
            await DatabaseService.insertLocalTask(task);
            downloadCount++;
          } catch (e) {
            debugPrint('❌ Failed to download task ${task.title}: $e');
          }
        }
      }

      debugPrint(
        '✅ Full sync completed: uploaded $uploadCount, downloaded $downloadCount',
      );
    } catch (e) {
      debugPrint('❌ Full sync error: $e');
    }
  }

  // Force sync a specific task
  static Future<bool> syncTask(Task task) async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    if (!await hasInternetConnection()) return false;

    try {
      await DatabaseService.syncToCloud(task);
      debugPrint('✅ Task synced successfully: ${task.title}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to sync task: $e');
      return false;
    }
  }

  // Get sync status
  static Future<Map<String, int>> getSyncStatus() async {
    try {
      final db = await DatabaseService.database;

      // Get total tasks
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM tasks',
      );
      final totalTasks = totalResult.first['count'] as int;

      // Get synced tasks (handle case where column doesn't exist)
      int syncedTasks = 0;
      try {
        final syncedResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM tasks WHERE synced = 1',
        );
        syncedTasks = syncedResult.first['count'] as int;
      } catch (e) {
        debugPrint('⚠️ Cannot get sync status: synced column not available');
      }

      return {
        'total': totalTasks,
        'synced': syncedTasks,
        'pending': totalTasks - syncedTasks,
      };
    } catch (e) {
      debugPrint('❌ Error getting sync status: $e');
      return {'total': 0, 'synced': 0, 'pending': 0};
    }
  }

  // Initialize sync service
  static void initialize() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('👤 User signed in, starting sync service');
        startPeriodicSync();
        // Perform initial sync
        Future.delayed(const Duration(seconds: 2), () => syncPendingTasks());
      } else {
        debugPrint('👤 User signed out, stopping sync service');
        stopSync();
      }
    });

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (!result.contains(ConnectivityResult.none) &&
          FirebaseAuth.instance.currentUser != null) {
        debugPrint('🌐 Internet connection restored, syncing pending tasks');
        Future.delayed(const Duration(seconds: 1), () => syncPendingTasks());
      }
    });
  }
}
