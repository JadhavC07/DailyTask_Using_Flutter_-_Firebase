// lib/widgets/edit_task_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/models/task.dart';
import 'package:myapp/utils/constants.dart';

class EditTaskDialog extends StatefulWidget {
  final Task task;

  const EditTaskDialog({super.key, required this.task});

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();
  late DateTime _taskDate;
  DateTime? _dueTime;
  bool _isLoading = false;
  bool _hasDueTime = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _taskDate = widget.task.date;
    _dueTime = widget.task.dueTime;
    _hasDueTime = widget.task.hasDueTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _taskDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (date != null && mounted) {
      setState(() {
        _taskDate = date;
        // Update due time if it exists
        if (_hasDueTime && _dueTime != null) {
          _dueTime = DateTime(
            date.year,
            date.month,
            date.day,
            _dueTime!.hour,
            _dueTime!.minute,
          );
        }
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime:
          _dueTime != null
              ? TimeOfDay.fromDateTime(_dueTime!)
              : TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      setState(() {
        _dueTime = DateTime(
          _taskDate.year,
          _taskDate.month,
          _taskDate.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  void _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate due time if enabled
    if (_hasDueTime && _dueTime != null) {
      final now = DateTime.now();
      // Allow past due times for editing existing tasks
      // Just show a warning for past due times
      if (_dueTime!.isBefore(now) && !widget.task.isCompleted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Past Due Time'),
                content: const Text(
                  'The due time you selected is in the past. The task will be marked as overdue. Continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
        );

        if (shouldContinue != true) return;
      }
    }

    setState(() => _isLoading = true);

    // Simulate a brief delay for better UX
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      final updatedTask = widget.task.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _taskDate,
        dueTime: _hasDueTime ? _dueTime : null,
      );
      Navigator.pop(context, updatedTask);
    }
  }

  Widget _buildDueTimeSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Due Time Toggle
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            color: colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              'Set Due Time',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              _hasDueTime ? 'Get notified before deadline' : 'No time limit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            secondary: Icon(
              _hasDueTime ? Icons.schedule_rounded : Icons.schedule_outlined,
              color:
                  _hasDueTime
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
            ),
            value: _hasDueTime,
            onChanged:
                _isLoading
                    ? null
                    : (value) {
                      setState(() {
                        _hasDueTime = value;
                        if (!value) {
                          _dueTime = null;
                        } else if (_dueTime == null) {
                          // Set default due time to end of selected day
                          _dueTime = DateTime(
                            _taskDate.year,
                            _taskDate.month,
                            _taskDate.day,
                            23,
                            59,
                          );
                        }
                      });
                    },
          ),
        ),

        // Time Picker (shown when due time is enabled)
        if (_hasDueTime) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              color: colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            child: ListTile(
              enabled: !_isLoading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Icon(
                Icons.access_time_rounded,
                color: colorScheme.primary,
              ),
              title: Text(
                'Due Time',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _dueTime != null
                    ? DateFormat('h:mm a').format(_dueTime!)
                    : 'Tap to set time',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: _selectTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
          ),

          // Due time preview
          if (_dueTime != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Due: ${DateFormat('EEEE, MMM dd \'at\' h:mm a').format(_dueTime!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: colorScheme.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Edit Task',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Task Title Field
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Task Title',
                    hintText: 'Enter your task...',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task title';
                    }
                    if (value.trim().length < 3) {
                      return 'Title must be at least 3 characters long';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 16),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Add details (optional)...',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  maxLines: 3,
                  minLines: 2,
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 16),

                // Date Selection
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                  child: ListTile(
                    enabled: !_isLoading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Icon(
                      Icons.calendar_today_outlined,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      'Due Date',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('EEEE, MMM dd, yyyy').format(_taskDate),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onTap: _selectDate,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Due Time Section
                _buildDueTimeSection(theme, colorScheme),

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius,
                            ),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleUpdate,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius,
                            ),
                          ),
                        ),
                        child:
                            _isLoading
                                ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                                : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Update Task'),
                                  ],
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
