import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.date,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  // Create Task from SQLite Map
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      isCompleted: map['isCompleted'] == 1, // Convert int to bool
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      completedAt:
          map['completedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
              : null,
    );
  }

  // Convert Task to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0, // Convert bool to int
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  // Create a copy with updated fields
  Task copyWith({
    String? title,
    String? description,
    DateTime? date,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      completedAt:
          isCompleted == false ? null : (completedAt ?? this.completedAt),
    );
  }

  @override
  String toString() {
    return 'Task{id: $id, title: $title, isCompleted: $isCompleted}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
