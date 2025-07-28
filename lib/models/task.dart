// lib/models/task.dart
import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? dueTime; // New field for specific due time
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.date,
    this.dueTime, // Optional due time
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  // Create a copy with updated fields
  Task copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? dueTime,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      dueTime: dueTime ?? this.dueTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // Convert to Map for local database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'dueTime': dueTime?.millisecondsSinceEpoch, // Store due time
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'synced': 0, // Default to unsynced
    };
  }

  // Create from Map (local database)
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      dueTime:
          map['dueTime'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['dueTime'])
              : null,
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      completedAt:
          map['completedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
              : null,
    );
  }

  // Helper methods for due time
  bool get hasDueTime => dueTime != null;

  bool get isOverdue {
    if (!hasDueTime || isCompleted) return false;
    return DateTime.now().isAfter(dueTime!);
  }

  bool get isDueSoon {
    if (!hasDueTime || isCompleted) return false;
    final now = DateTime.now();
    final timeDiff = dueTime!.difference(now);
    return timeDiff.inHours <= 2 && timeDiff.inMinutes > 0;
  }

  Duration? get timeUntilDue {
    if (!hasDueTime || isCompleted) return null;
    return dueTime!.difference(DateTime.now());
  }

  String get dueStatus {
    if (!hasDueTime) return 'No due time';
    if (isCompleted) return 'Completed';
    if (isOverdue) return 'Overdue';
    if (isDueSoon) return 'Due soon';
    return 'On track';
  }
}
