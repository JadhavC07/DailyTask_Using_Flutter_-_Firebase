import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

enum TaskAction { edit, delete, markComplete, markIncomplete }

class TaskActionsSheet extends StatelessWidget {
  final Task task;

  const TaskActionsSheet({super.key, required this.task});

  static Future<TaskAction?> show(BuildContext context, Task task) {
    return showModalBottomSheet<TaskAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TaskActionsSheet(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Task info header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        task.isCompleted
                            ? Colors.green.withOpacity(0.1)
                            : colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    task.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.task_alt_rounded,
                    color:
                        task.isCompleted
                            ? Colors.green[600]
                            : colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(task.date),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (task.hasDueTime) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color:
                                  task.isOverdue
                                      ? Colors.red[600]
                                      : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('h:mm a').format(task.dueTime!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    task.isOverdue
                                        ? Colors.red[600]
                                        : colorScheme.onSurfaceVariant,
                                fontWeight:
                                    task.isOverdue
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Complete/Incomplete toggle
                _buildActionTile(
                  context: context,
                  icon:
                      task.isCompleted
                          ? Icons.undo_rounded
                          : Icons.check_circle_rounded,
                  title:
                      task.isCompleted
                          ? 'Mark as Incomplete'
                          : 'Mark as Complete',
                  subtitle:
                      task.isCompleted
                          ? 'Move back to pending tasks'
                          : 'Mark this task as done',
                  color:
                      task.isCompleted
                          ? colorScheme.primary
                          : Colors.green[600]!,
                  backgroundColor:
                      task.isCompleted
                          ? colorScheme.primaryContainer.withOpacity(0.3)
                          : Colors.green.withOpacity(0.1),
                  onTap:
                      () => Navigator.pop(
                        context,
                        task.isCompleted
                            ? TaskAction.markIncomplete
                            : TaskAction.markComplete,
                      ),
                ),

                const SizedBox(height: 8),

                // Edit task
                _buildActionTile(
                  context: context,
                  icon: Icons.edit_rounded,
                  title: 'Edit Task',
                  subtitle: 'Modify title, description, or due time',
                  color: colorScheme.secondary,
                  backgroundColor: colorScheme.secondaryContainer.withOpacity(
                    0.3,
                  ),
                  onTap: () => Navigator.pop(context, TaskAction.edit),
                ),

                const SizedBox(height: 8),

                // Delete task
                _buildActionTile(
                  context: context,
                  icon: Icons.delete_rounded,
                  title: 'Delete Task',
                  subtitle: 'Permanently remove this task',
                  color: Colors.red[600]!,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  onTap: () => Navigator.pop(context, TaskAction.delete),
                ),
              ],
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
