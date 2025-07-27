import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmptyStateWidget extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onAddTask;

  const EmptyStateWidget({
    super.key,
    required this.selectedDate,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No tasks for ${DateFormat('MMM dd').format(selectedDate)}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first task',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Task'),
          ),
        ],
      ),
    );
  }
}
