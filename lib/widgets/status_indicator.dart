import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class StatusIndicator extends StatelessWidget {
  final int taskCount;

  const StatusIndicator({super.key, required this.taskCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      authService.isAuthenticated
                          ? Colors.green.withOpacity(0.1)
                          : theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  authService.isAuthenticated
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  size: 16,
                  color:
                      authService.isAuthenticated
                          ? Colors.green[600]
                          : theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                authService.isAuthenticated
                    ? 'Synced with Cloud'
                    : 'Offline Mode',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '$taskCount task${taskCount != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
