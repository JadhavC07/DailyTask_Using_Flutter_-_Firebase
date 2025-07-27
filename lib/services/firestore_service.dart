import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // Collection reference for user's tasks
  CollectionReference get _tasksCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('tasks');
  }

  // Add a new task to Firestore
  Future<String?> addTask({
    required String title,
    String? description,
    DateTime? dueDate,
    bool isCompleted = false,
    String priority = 'medium',
  }) async {
    try {
      if (_userId == null) {
        debugPrint('❌ User not authenticated');
        return null;
      }

      final taskData = {
        'title': title,
        'description': description ?? '',
        'dueDate': dueDate?.toIso8601String(),
        'isCompleted': isCompleted,
        'priority': priority,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': _userId,
      };

      debugPrint('📝 Adding task to Firestore: $title');
      
      final DocumentReference docRef = await _tasksCollection.add(taskData);
      
      debugPrint('✅ Task added successfully with ID: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      debugPrint('❌ Error adding task to Firestore: $e');
      return null;
    }
  }

  // Get all tasks for the current user
  Stream<List<Task>> getTasks() {
    if (_userId == null) {
      debugPrint('❌ User not authenticated, returning empty stream');
      return Stream.value([]);
    }

    return _tasksCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('📱 Fetched ${snapshot.docs.length} tasks from Firestore');
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Task.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  // Update task completion status
  Future<bool> updateTaskCompletion(String taskId, bool isCompleted) async {
    try {
      if (_userId == null) return false;

      await _tasksCollection.doc(taskId).update({
        'isCompleted': isCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Task completion updated: $taskId -> $isCompleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating task completion: $e');
      return false;
    }
  }

  // Update task details
  Future<bool> updateTask({
    required String taskId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
  }) async {
    try {
      if (_userId == null) return false;

      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (dueDate != null) updates['dueDate'] = dueDate.toIso8601String();
      if (priority != null) updates['priority'] = priority;

      await _tasksCollection.doc(taskId).update(updates);

      debugPrint('✅ Task updated successfully: $taskId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
      return false;
    }
  }

  // Delete a task
  Future<bool> deleteTask(String taskId) async {
    try {
      if (_userId == null) return false;

      await _tasksCollection.doc(taskId).delete();

      debugPrint('✅ Task deleted successfully: $taskId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting task: $e');
      return false;
    }
  }

  // Get task count for the current user
  Future<int> getTaskCount() async {
    try {
      if (_userId == null) return 0;

      final QuerySnapshot snapshot = await _tasksCollection.get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting task count: $e');
      return 0;
    }
  }

  // Get completed task count
  Future<int> getCompletedTaskCount() async {
    try {
      if (_userId == null) return 0;

      final QuerySnapshot snapshot = await _tasksCollection
          .where('isCompleted', isEqualTo: true)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting completed task count: $e');
      return 0;
    }
  }

  // Search tasks by title
  Stream<List<Task>> searchTasks(String query) {
    if (_userId == null || query.isEmpty) {
      return Stream.value([]);
    }

    return _tasksCollection
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Task.fromFirestore(doc.id, data);
      }).toList();
    });
  }
}

// Updated Task model to work with Firestore
class Task {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final bool isCompleted;
  final String priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String userId;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.isCompleted = false,
    this.priority = 'medium',
    required this.createdAt,
    this.updatedAt,
    required this.userId,
  });

  // Create Task from Firestore document
  factory Task.fromFirestore(String id, Map<String, dynamic> data) {
    return Task(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dueDate: data['dueDate'] != null ? DateTime.parse(data['dueDate']) : null,
      isCompleted: data['isCompleted'] ?? false,
      priority: data['priority'] ?? 'medium',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      userId: data['userId'] ?? '',
    );
  }

  // Convert Task to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'userId': userId,
    };
  }

  // Create a copy with updated fields
  Task copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    String? priority,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      userId: userId,
    );
  }
}