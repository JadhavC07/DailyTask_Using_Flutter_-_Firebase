import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskStats extends StatelessWidget {
  final List<Task> tasks;

  const TaskStats({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final totalTasks = tasks.length;
    final completionRate = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Today\'s Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  totalTasks.toString(),
                  Icons.list_alt,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Completed',
                  completedTasks.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatItem(
                  'Pending',
                  (totalTasks - completedTasks).toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: completionRate,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                completionRate == 1.0 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(completionRate * 100).toInt()}% Complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}