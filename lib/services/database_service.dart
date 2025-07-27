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
    String path = join(await getDatabasesPath(), 'tasks.db');

    return await openDatabase(
      path,
      version: 2, // Increased version for schema update
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            date INTEGER NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            completedAt INTEGER,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Check if synced column already exists
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
            } else {
              debugPrint('ℹ️ Synced column already exists, skipping migration');
            }
          } catch (e) {
            debugPrint('❌ Error during database migration: $e');
            // If there's any error, try to continue without the column
            // The app will still work, just without sync status tracking
          }
        }
      },
    );
  }

  // Get current user ID
  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Local CRUD Operations
  static Future<List<Task>> getLocalTasks({DateTime? date}) async {
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
  }

  static Future<void> insertLocalTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('✅ Task saved locally: ${task.title}');
  }

  static Future<void> updateLocalTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    debugPrint('✅ Task updated locally: ${task.title}');
  }

  static Future<void> deleteLocalTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Cloud Operations (Firebase Firestore)
  static Future<void> syncToCloud(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot sync to cloud: User not authenticated');
      return;
    }

    // Check if Firestore is available before syncing
    if (!await isFirestoreAvailable()) {
      debugPrint('❌ Skipping cloud sync: Firestore database not available');
      debugPrint(
        '🔥 Create database at: https://console.cloud.google.com/datastore/setup?project=taskdaily-77b75',
      );
      return;
    }

    try {
      // Your existing sync code here...
      final taskData = {
        'title': task.title,
        'description': task.description,
        'date': task.date.millisecondsSinceEpoch,
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
          // Convert Firestore data to Task
          final task = Task(
            id: doc.id,
            title: data['title'] ?? '',
            description: data['description'] ?? '',
            date: DateTime.fromMillisecondsSinceEpoch(data['date'] ?? 0),
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

      // Try to get unsynced tasks, but handle the case where synced column doesn't exist
      List<Map<String, dynamic>> unsyncedTasks = [];
      try {
        unsyncedTasks = await db.query(
          'tasks',
          where: 'synced = ? OR synced IS NULL',
          whereArgs: [0],
        );
      } catch (e) {
        debugPrint('⚠️ Synced column not available, syncing all tasks: $e');
        // If synced column doesn't exist, get all tasks
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
    final cloudTasks = await getCloudTasks();
    final db = await database;

    for (var task in cloudTasks) {
      try {
        await db.insert('tasks', {
          ...task.toMap(),
          'synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        // If synced column doesn't exist, insert without it
        await db.insert(
          'tasks',
          task.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    debugPrint('✅ Synced ${cloudTasks.length} tasks from cloud to local');
  }

  // Helper method to check if synced column exists
  static Future<bool> _syncedColumnExists() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info(tasks)',
      );
      return columns.any((column) => column['name'] == 'synced');
    } catch (e) {
      debugPrint('❌ Error checking synced column: $e');
      return false;
    }
  }

  static Future<bool> isFirestoreAvailable() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Try a simple test query
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
}
