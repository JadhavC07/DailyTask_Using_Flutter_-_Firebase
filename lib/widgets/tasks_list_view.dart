import 'package:flutter/material.dart';
import '../models/task.dart';
import '../widgets/task_tile.dart';

class TasksListView extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task) onToggleTask;
  final Future<void> Function() onRefresh;

  const TasksListView({
    super.key,
    required this.tasks,
    required this.onToggleTask,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return TaskTile(
            task: tasks[index],
            onToggle: () => onToggleTask(tasks[index]),
          );
        },
      ),
    );
  }
}
