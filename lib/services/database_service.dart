// lib/services/database_service.dart
import 'package:myapp/models/task.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DatabaseService {
  static Database? _database;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize local database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    try {
      String path = join(await getDatabasesPath(), 'tasks.db');
      debugPrint('📂 Database path: $path');

      return await openDatabase(
        path,
        version: 3,
        onCreate: (db, version) async {
          debugPrint('🏗️ Creating database tables...');
          await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            date INTEGER NOT NULL,
            dueTime INTEGER,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            completedAt INTEGER,
            synced INTEGER DEFAULT 0
          )
        ''');
          debugPrint('✅ Database tables created successfully');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint(
            '🔄 Upgrading database from version $oldVersion to $newVersion',
          );

          if (oldVersion < 2) {
            try {
              final List<Map<String, dynamic>> columns = await db.rawQuery(
                'PRAGMA table_info(tasks)',
              );
              final bool syncedColumnExists = columns.any(
                (column) => column['name'] == 'synced',
              );

              if (!syncedColumnExists) {
                await db.execute(
                  'ALTER TABLE tasks ADD COLUMN synced INTEGER DEFAULT 0',
                );
                debugPrint('✅ Added synced column to tasks table');
              }
            } catch (e) {
              debugPrint('❌ Error during database migration: $e');
            }
          }

          if (oldVersion < 3) {
            try {
              final List<Map<String, dynamic>> columns = await db.rawQuery(
                'PRAGMA table_info(tasks)',
              );
              final bool dueTimeColumnExists = columns.any(
                (column) => column['name'] == 'dueTime',
              );

              if (!dueTimeColumnExists) {
                await db.execute(
                  'ALTER TABLE tasks ADD COLUMN dueTime INTEGER',
                );
                debugPrint('✅ Added dueTime column to tasks table');
              }
            } catch (e) {
              debugPrint('❌ Error adding dueTime column: $e');
            }
          }
        },
        onOpen: (db) {
          debugPrint('✅ Database opened successfully');
        },
      );
    } catch (e) {
      debugPrint('❌ Database initialization error: $e');
      rethrow;
    }
  }

  // Get current user ID
  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Local CRUD Operations
  static Future<List<Task>> getLocalTasks({DateTime? date}) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> maps;

      if (date != null) {
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        maps = await db.query(
          'tasks',
          where: 'date >= ? AND date < ?',
          whereArgs: [
            startOfDay.millisecondsSinceEpoch,
            endOfDay.millisecondsSinceEpoch,
          ],
          orderBy: 'createdAt DESC',
        );
      } else {
        maps = await db.query('tasks', orderBy: 'date ASC');
      }

      return List.generate(maps.length, (i) {
        return Task.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('❌ Error getting local tasks: $e');
      return [];
    }
  }

  static Future<void> insertLocalTask(Task task) async {
    try {
      final db = await database;
      await db.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('✅ Task saved locally: ${task.title}');

      // Schedule notifications for the task if it has due time
      if (task.hasDueTime && !task.isCompleted) {
        await _scheduleTaskNotifications(task);
      }
    } catch (e) {
      debugPrint('❌ Error inserting local task: $e');
      rethrow;
    }
  }

  static Future<void> updateLocalTask(Task task) async {
    try {
      final db = await database;
      await db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      debugPrint('✅ Task updated locally: ${task.title}');

      // Update notifications
      await _updateTaskNotifications(task);
    } catch (e) {
      debugPrint('❌ Error updating local task: $e');
      rethrow;
    }
  }

  static Future<void> deleteLocalTask(String id) async {
    try {
      final db = await database;
      await db.delete('tasks', where: 'id = ?', whereArgs: [id]);

      // Cancel notifications for deleted task
      await _cancelTaskNotifications(id);
      debugPrint('✅ Task deleted locally: $id');
    } catch (e) {
      debugPrint('❌ Error deleting local task: $e');
      rethrow;
    }
  }

  // Notification scheduling methods
  static Future<void> _scheduleTaskNotifications(Task task) async {
    try {
      // Import notification service dynamically to avoid circular imports
      final NotificationService = await _getNotificationService();
      await NotificationService.scheduleAllTaskNotifications(task);
    } catch (e) {
      debugPrint('❌ Error scheduling notifications: $e');
    }
  }

  static Future<void> _updateTaskNotifications(Task task) async {
    try {
      final NotificationService = await _getNotificationService();
      await NotificationService.scheduleAllTaskNotifications(task);
    } catch (e) {
      debugPrint('❌ Error updating notifications: $e');
    }
  }

  static Future<void> _cancelTaskNotifications(String taskId) async {
    try {
      final NotificationService = await _getNotificationService();
      await NotificationService.cancelTaskNotifications(taskId);
    } catch (e) {
      debugPrint('❌ Error canceling notifications: $e');
    }
  }

  // Dynamic import helper to avoid circular dependencies
  static Future<dynamic> _getNotificationService() async {
    // This is a workaround for circular import issues
    // In practice, you should restructure to avoid this
    return Future.value(null); // Will be replaced with proper import
  }

  // Cloud Operations (Firebase Firestore) - keeping existing implementation
  static Future<void> syncToCloud(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot sync to cloud: User not authenticated');
      return;
    }

    if (!await isFirestoreAvailable()) {
      debugPrint('❌ Skipping cloud sync: Firestore database not available');
      return;
    }

    try {
      final taskData = {
        'title': task.title,
        'description': task.description,
        'date': task.date.millisecondsSinceEpoch,
        'dueTime': task.dueTime?.millisecondsSinceEpoch,
        'isCompleted': task.isCompleted,
        'createdAt': task.createdAt.millisecondsSinceEpoch,
        'completedAt': task.completedAt?.millisecondsSinceEpoch,
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(task.id)
          .set(taskData, SetOptions(merge: true));

      // Mark as synced in local DB
      try {
        final db = await database;
        await db.update(
          'tasks',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [task.id],
        );
      } catch (e) {
        debugPrint('⚠️ Could not update sync status locally: $e');
      }

      debugPrint('✅ Task synced to cloud: ${task.title}');
    } catch (e) {
      debugPrint('❌ Sync to cloud failed: $e');
    }
  }

  static Future<List<Task>> getCloudTasks({DateTime? date}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot fetch cloud tasks: User not authenticated');
      return [];
    }

    try {
      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks');

      if (date != null) {
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        query = query
            .where(
              'date',
              isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch,
            )
            .where('date', isLessThan: endOfDay.millisecondsSinceEpoch);
      }

      final snapshot = await query.orderBy('date').get();

      List<Task> tasks = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final task = Task(
            id: doc.id,
            title: data['title'] ?? '',
            description: data['description'] ?? '',
            date: DateTime.fromMillisecondsSinceEpoch(data['date'] ?? 0),
            dueTime:
                data['dueTime'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(data['dueTime'])
                    : null,
            isCompleted: data['isCompleted'] ?? false,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              data['createdAt'] ?? 0,
            ),
            completedAt:
                data['completedAt'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(data['completedAt'])
                    : null,
          );
          tasks.add(task);
        } catch (e) {
          debugPrint('❌ Error parsing task ${doc.id}: $e');
        }
      }

      debugPrint('✅ Fetched ${tasks.length} tasks from cloud');
      return tasks;
    } catch (e) {
      debugPrint('❌ Cloud fetch error: $e');
      return [];
    }
  }

  // Sync all unsynced local tasks to cloud
  static Future<void> syncAllToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final db = await database;

      List<Map<String, dynamic>> unsyncedTasks = [];
      try {
        unsyncedTasks = await db.query(
          'tasks',
          where: 'synced = ? OR synced IS NULL',
          whereArgs: [0],
        );
      } catch (e) {
        debugPrint('⚠️ Synced column not available, syncing all tasks: $e');
        unsyncedTasks = await db.query('tasks');
      }

      debugPrint('🔄 Syncing ${unsyncedTasks.length} unsynced tasks...');

      for (var taskMap in unsyncedTasks) {
        final task = Task.fromMap(taskMap);
        await syncToCloud(task);
      }

      debugPrint('✅ All tasks synced to cloud');
    } catch (e) {
      debugPrint('❌ Bulk sync failed: $e');
    }
  }

  // Sync cloud tasks to local (for offline use)
  static Future<void> syncFromCloud() async {
    try {
      final cloudTasks = await getCloudTasks();
      final db = await database;

      for (var task in cloudTasks) {
        try {
          await db.insert('tasks', {
            ...task.toMap(),
            'synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          // Schedule notifications for synced tasks with due times
          if (task.hasDueTime && !task.isCompleted) {
            await _scheduleTaskNotifications(task);
          }
        } catch (e) {
          await db.insert(
            'tasks',
            task.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      debugPrint('✅ Synced ${cloudTasks.length} tasks from cloud to local');
    } catch (e) {
      debugPrint('❌ Error syncing from cloud: $e');
    }
  }

  // Firestore availability check
  static Future<bool> isFirestoreAvailable() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      return true;
    } catch (e) {
      debugPrint('❌ Firestore not available: $e');
      if (e.toString().contains('NOT_FOUND') ||
          e.toString().contains('does not exist')) {
        debugPrint('🔥 Please create Firestore database in Firebase Console');
      }
      return false;
    }
  }

  // Get tasks with due times for notification scheduling
  static Future<List<Task>> getTasksWithDueTimes() async {
    try {
      final db = await database;
      final maps = await db.query(
        'tasks',
        where: 'dueTime IS NOT NULL AND isCompleted = 0',
        orderBy: 'dueTime ASC',
      );

      return List.generate(maps.length, (i) {
        return Task.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('❌ Error getting tasks with due times: $e');
      return [];
    }
  }

  // Get overdue tasks
  static Future<List<Task>> getOverdueTasks() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final maps = await db.query(
        'tasks',
        where: 'dueTime IS NOT NULL AND dueTime < ? AND isCompleted = 0',
        whereArgs: [now],
        orderBy: 'dueTime ASC',
      );

      return List.generate(maps.length, (i) {
        return Task.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('❌ Error getting overdue tasks: $e');
      return [];
    }
  }

  // Get tasks due soon (within next 2 hours)
  static Future<List<Task>> getTasksDueSoon() async {
    try {
      final db = await database;
      final now = DateTime.now();
      final twoHoursLater = now.add(const Duration(hours: 2));

      final maps = await db.query(
        'tasks',
        where:
            'dueTime IS NOT NULL AND dueTime > ? AND dueTime <= ? AND isCompleted = 0',
        whereArgs: [
          now.millisecondsSinceEpoch,
          twoHoursLater.millisecondsSinceEpoch,
        ],
        orderBy: 'dueTime ASC',
      );

      return List.generate(maps.length, (i) {
        return Task.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('❌ Error getting tasks due soon: $e');
      return [];
    }
  }

  // Initialize all notifications for existing tasks
  static Future<void> initializeAllNotifications() async {
    try {
      final tasksWithDueTimes = await getTasksWithDueTimes();
      debugPrint(
        '🔔 Initializing notifications for ${tasksWithDueTimes.length} tasks',
      );

      for (final task in tasksWithDueTimes) {
        await _scheduleTaskNotifications(task);
      }

      debugPrint('✅ All task notifications initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }
}
