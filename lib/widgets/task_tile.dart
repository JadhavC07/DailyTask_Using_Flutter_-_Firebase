import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/utils/constants.dart';
import 'package:myapp/services/database_service.dart'; // Add this import
import '../models/task.dart';
import 'task_actions_sheet.dart';
import 'edit_task_dialog.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(Task)? onTaskUpdated; // Callback for when task is updated
  final VoidCallback? onTaskDeleted; // Callback for when task is deleted

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    this.onLongPress,
    this.onEdit,
    this.onDelete,
    this.onTaskUpdated,
    this.onTaskDeleted,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDeleting = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat('MMM dd').format(dateTime);
  }

  // Handle task actions from the bottom sheet
  Future<void> _handleTaskAction(BuildContext context) async {
    if (_isDeleting || _isUpdating) return;

    final action = await TaskActionsSheet.show(context, widget.task);

    if (!mounted || action == null) return;

    switch (action) {
      case TaskAction.edit:
        await _handleEditTask(context);
        break;
      case TaskAction.delete:
        await _handleDeleteTask(context);
        break;
      case TaskAction.markComplete:
      case TaskAction.markIncomplete:
        widget.onToggle();
        break;
    }
  }

  // FIXED: Handle edit task with proper error handling
  Future<void> _handleEditTask(BuildContext context) async {
    if (_isUpdating) return;

    try {
      setState(() => _isUpdating = true);

      final updatedTask = await showDialog<Task>(
        context: context,
        barrierDismissible: false, // Prevent dismissing during loading
        builder: (context) => EditTaskDialog(task: widget.task),
      );

      if (!mounted || updatedTask == null) return;

      try {
        // Update the task in the database
        await DatabaseService.updateTask(updatedTask);

        // Notify parent widget
        if (widget.onTaskUpdated != null) {
          widget.onTaskUpdated!(updatedTask);
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Task "${updatedTask.title}" updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Failed to update task: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Failed to update task. Please try again.'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in edit task dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  // FIXED: Handle delete task with proper error handling and animation
  Future<void> _handleDeleteTask(BuildContext context) async {
    if (_isDeleting) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text(
              'Are you sure you want to delete "${widget.task.title}"?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() => _isDeleting = true);

      // Animate out the tile
      await _animationController.reverse();

      // Delete the task from database
      await DatabaseService.deleteTask(widget.task.id);

      if (mounted) {
        // Notify parent widget
        if (widget.onTaskDeleted != null) {
          widget.onTaskDeleted!();
        } else if (widget.onDelete != null) {
          widget.onDelete!();
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete, color: Colors.white),
                const SizedBox(width: 8),
                Text('Task "${widget.task.title}" deleted'),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Implement undo functionality if needed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Undo is not yet implemented'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to delete task: $e');

      // Restore animation if delete failed
      if (mounted) {
        await _animationController.forward();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Failed to delete task. Please try again.'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Widget _buildDueTimeIndicator(ThemeData theme) {
    if (!widget.task.hasDueTime) return const SizedBox.shrink();

    final colorScheme = theme.colorScheme;
    final dueTime = widget.task.dueTime!;
    final now = DateTime.now();
    final isOverdue = widget.task.isOverdue;
    final isDueSoon = widget.task.isDueSoon;

    Color indicatorColor;
    IconData indicatorIcon;
    String timeText;

    if (widget.task.isCompleted) {
      indicatorColor = Colors.green;
      indicatorIcon = Icons.check_circle_rounded;
      timeText = 'Completed on time';
    } else if (isOverdue) {
      indicatorColor = Colors.red;
      indicatorIcon = Icons.warning_rounded;
      final overdueDuration = now.difference(dueTime);
      timeText = 'Overdue by ${_formatDuration(overdueDuration)}';
    } else if (isDueSoon) {
      indicatorColor = Colors.orange;
      indicatorIcon = Icons.schedule_rounded;
      final timeUntilDue = dueTime.difference(now);
      timeText = 'Due in ${_formatDuration(timeUntilDue)}';
    } else {
      indicatorColor = colorScheme.primary;
      indicatorIcon = Icons.access_time_rounded;
      timeText = 'Due at ${DateFormat('h:mm a').format(dueTime)}';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(indicatorIcon, size: 14, color: indicatorColor),
          const SizedBox(width: 4),
          Text(
            timeText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: indicatorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays != 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours != 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes != 1 ? 's' : ''}';
    }
  }

  Widget _buildStatusIndicator(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    if (widget.task.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Colors.green[600],
            ),
            const SizedBox(width: 4),
            Text(
              'Done',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Check if task is overdue (considering due time if available)
    bool isOverdue = false;
    if (widget.task.hasDueTime) {
      isOverdue = widget.task.isOverdue;
    } else {
      // Fallback to date-based overdue check
      isOverdue =
          widget.task.date.isBefore(DateTime.now()) &&
          !_isToday(widget.task.date);
    }

    if (isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_rounded, size: 14, color: Colors.red[600]),
            const SizedBox(width: 4),
            Text(
              'Overdue',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.red[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Check if task is due soon
    if (widget.task.isDueSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: Colors.orange[600]),
            const SizedBox(width: 4),
            Text(
              'Due Soon',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Today's task
    if (_isToday(widget.task.date)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.today_rounded, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              'Today',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildActionButtons(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Button
        IconButton(
          onPressed: () => _handleEditTask(context),
          icon: const Icon(Icons.edit_outlined),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.secondaryContainer.withOpacity(0.3),
            foregroundColor: colorScheme.secondary,
            minimumSize: const Size(36, 36),
          ),
          tooltip: 'Edit task',
        ),

        const SizedBox(width: 4),

        // Delete Button
        IconButton(
          onPressed: () => _handleDeleteTask(context),
          icon: const Icon(Icons.delete_outline_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            foregroundColor: Colors.red[600],
            minimumSize: const Size(36, 36),
          ),
          tooltip: 'Delete task',
        ),

        const SizedBox(width: 4),

        // More Options Button
        IconButton(
          onPressed: () => _handleTaskAction(context),
          icon: const Icon(Icons.more_vert_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
            foregroundColor: colorScheme.onSurfaceVariant,
            minimumSize: const Size(36, 36),
          ),
          tooltip: 'More options',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = widget.task.isCompleted;

    // Determine border color based on task status
    Color borderColor;
    if (isCompleted) {
      borderColor = Colors.green.withOpacity(0.3);
    } else if (widget.task.isOverdue) {
      borderColor = Colors.red.withOpacity(0.5);
    } else if (widget.task.isDueSoon) {
      borderColor = Colors.orange.withOpacity(0.5);
    } else {
      borderColor = colorScheme.outline.withOpacity(0.2);
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  AppConstants.borderRadius * 1.5,
                ),
                border: Border.all(
                  color: borderColor,
                  width: widget.task.isOverdue ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onToggle,
                  onLongPress:
                      widget.onLongPress ?? () => _handleTaskAction(context),
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius * 1.5,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Custom Checkbox
                        GestureDetector(
                          onTap: widget.onToggle,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  isCompleted
                                      ? Colors.green
                                      : Colors.transparent,
                              border: Border.all(
                                color:
                                    isCompleted
                                        ? Colors.green
                                        : colorScheme.outline,
                                width: 2,
                              ),
                            ),
                            child:
                                isCompleted
                                    ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                    : null,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Task Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Status Row
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.task.title,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            decoration:
                                                isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                            color:
                                                isCompleted
                                                    ? colorScheme
                                                        .onSurfaceVariant
                                                    : colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusIndicator(theme),
                                ],
                              ),

                              // Description
                              if (widget.task.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  widget.task.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        isCompleted
                                            ? colorScheme.onSurfaceVariant
                                                .withOpacity(0.7)
                                            : colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              // Due Time Indicator
                              if (widget.task.hasDueTime)
                                _buildDueTimeIndicator(theme),

                              const SizedBox(height: 8),

                              // Metadata Row
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant
                                        .withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getRelativeTime(widget.task.createdAt),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant
                                          .withOpacity(0.8),
                                    ),
                                  ),

                                  if (widget.task.completedAt != null) ...[
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 14,
                                      color: Colors.green.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Completed ${_getRelativeTime(widget.task.completedAt!)}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: Colors.green[600]),
                                    ),
                                  ],

                                  const Spacer(),

                                  // Due date (only show if not today)
                                  if (!_isToday(widget.task.date))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceVariant
                                            .withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        DateHelpers.getRelativeDateString(
                                          widget.task.date,
                                        ),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Action Buttons
                        _buildActionButtons(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
