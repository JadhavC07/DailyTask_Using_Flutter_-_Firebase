import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/widgets/add_task_dialog.dart';
import 'package:myapp/widgets/date_selector.dart';
import 'package:myapp/widgets/empty_state_widget.dart';
import 'package:myapp/widgets/loading_widget.dart';
import 'package:myapp/widgets/settings_menu.dart';
import 'package:myapp/widgets/status_indicator.dart';
import 'package:myapp/widgets/tasks_list_view.dart';
import 'package:myapp/widgets/theme_toggle_button.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime selectedDate = DateTime.now();
  List<Task> tasks = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came to foreground, check for immediate notifications
      _checkImmediateNotifications();
    }
  }

  Future<void> _initializeScreen() async {
    await _loadTasks();
    await _setupNotifications();
    await _checkImmediateNotifications();
  }

  Future<void> _setupNotifications() async {
    try {
      // Setup daily reminder
      await NotificationService.scheduleDailyReminder();

      debugPrint('✅ Notifications setup completed');
    } catch (e) {
      debugPrint('❌ Error setting up notifications: $e');
    }
  }

  Future<void> _checkImmediateNotifications() async {
    try {
      await NotificationService.checkAndSendImmediateNotifications();
    } catch (e) {
      debugPrint('❌ Error checking immediate notifications: $e');
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final tasks = await compute(_loadTasksInBackground, {
        'isAuthenticated': authService.isAuthenticated,
        'isOfflineMode': await authService.isOfflineMode(),
        'selectedDate': selectedDate.millisecondsSinceEpoch,
      });

      if (!mounted) return;

      setState(() {
        this.tasks = tasks;
      });
      debugPrint('✅ Loaded ${tasks.length} tasks');
    } catch (e) {
      debugPrint('❌ Load tasks error: $e');
      if (!mounted) return;

      try {
        final localTasks = await DatabaseService.getLocalTasks(
          date: selectedDate,
        );
        setState(() {
          tasks = localTasks;
        });
      } catch (localError) {
        debugPrint('❌ Local tasks error: $localError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load tasks: ${localError.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  static Future<List<Task>> _loadTasksInBackground(
    Map<String, dynamic> params,
  ) async {
    final isAuthenticated = params['isAuthenticated'] as bool;
    final isOfflineMode = params['isOfflineMode'] as bool;
    final selectedDate = DateTime.fromMillisecondsSinceEpoch(
      params['selectedDate'],
    );

    try {
      if (isAuthenticated && !isOfflineMode) {
        final cloudTasks = await DatabaseService.getCloudTasks(
          date: selectedDate,
        );

        if (cloudTasks.isNotEmpty) {
          await Future.wait(
            cloudTasks.map((task) => DatabaseService.insertLocalTask(task)),
          );
        }

        return cloudTasks;
      } else {
        return await DatabaseService.getLocalTasks(date: selectedDate);
      }
    } catch (e) {
      return await DatabaseService.getLocalTasks(date: selectedDate);
    }
  }

  Future<void> _addTask() async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => AddTaskDialog(selectedDate: selectedDate),
    );

    if (result != null && mounted) {
      debugPrint('📝 Adding new task: ${result.title}');

      setState(() {
        tasks = [...tasks, result];
      });

      await _saveTaskInBackground(result);
    }
  }

  Future<void> _saveTaskInBackground(Task task) async {
    try {
      await DatabaseService.insertLocalTask(task);

      // Schedule notifications for the new task
      if (task.hasDueTime && !task.isCompleted) {
        await NotificationService.scheduleAllTaskNotifications(task);
        debugPrint('🔔 Notifications scheduled for new task: ${task.title}');
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated && !await authService.isOfflineMode()) {
        await DatabaseService.syncToCloud(task);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.hasDueTime
                        ? 'Task saved and notifications scheduled'
                        : 'Task saved successfully',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Background save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onError,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to save task: ${e.toString()}')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    debugPrint('🔄 Toggling task completion: ${task.title}');

    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );

    // Optimistic update
    setState(() {
      final taskIndex = tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        tasks[taskIndex] = updatedTask;
      }
    });

    try {
      await DatabaseService.updateLocalTask(updatedTask);

      // Update notifications based on completion status
      if (updatedTask.isCompleted) {
        // Cancel notifications when task is completed
        await NotificationService.cancelTaskNotifications(updatedTask.id);
        debugPrint(
          '🚫 Cancelled notifications for completed task: ${updatedTask.title}',
        );
      } else if (updatedTask.hasDueTime) {
        // Reschedule notifications when task is marked as incomplete
        await NotificationService.scheduleAllTaskNotifications(updatedTask);
        debugPrint(
          '🔔 Rescheduled notifications for incomplete task: ${updatedTask.title}',
        );
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated && !await authService.isOfflineMode()) {
        await DatabaseService.syncToCloud(updatedTask);
      }

      // Show completion feedback
      if (mounted && updatedTask.isCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Great job! "${updatedTask.title}" completed'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Toggle task error: $e');
      // Revert optimistic update
      setState(() {
        final taskIndex = tasks.indexWhere((t) => t.id == updatedTask.id);
        if (taskIndex != -1) {
          tasks[taskIndex] = task;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _syncTasks() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isAuthenticated) {
      final result = await authService.signInWithGoogle();
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Sign in failed'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      await DatabaseService.syncAllToCloud();
      await DatabaseService.syncFromCloud();
      await _loadTasks();

      // Reschedule notifications after sync
      await NotificationService.rescheduleAllNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.white),
                SizedBox(width: 8),
                Text('Tasks synced and notifications updated'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync_problem, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Sync failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Helper method to show notification permission dialog
  Future<void> _checkNotificationPermissions() async {
    final areEnabled = await NotificationService.areNotificationsEnabled();

    if (!areEnabled && mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Enable Notifications'),
              content: const Text(
                'To receive timely reminders for your tasks, please enable notifications in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    NotificationService.openNotificationSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Daily Tasks',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: theme.colorScheme.primary,
        actions: [
          // Notification permission check button
          IconButton(
            onPressed: _checkNotificationPermissions,
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Check Notifications',
          ),

          // Theme toggle button
          const ThemeToggleButton(),
          const SizedBox(width: 8),

          // Settings menu
          SettingsMenu(onSyncTasks: _syncTasks, onLoadTasks: _loadTasks),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Date Selector
          DateSelector(
            selectedDate: selectedDate,
            onDateChanged: (date) {
              setState(() => selectedDate = date);
              _loadTasks();
            },
          ),

          // Status indicator
          StatusIndicator(taskCount: tasks.length),

          // Tasks List
          Expanded(
            child:
                isLoading
                    ? const LoadingWidget()
                    : tasks.isEmpty
                    ? EmptyStateWidget(
                      selectedDate: selectedDate,
                      onAddTask: _addTask,
                    )
                    : TasksListView(
                      tasks: tasks,
                      onToggleTask: _toggleTaskCompletion,
                      onRefresh: _loadTasks,
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Task'),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        elevation: 3,
      ),
    );
  }
}
