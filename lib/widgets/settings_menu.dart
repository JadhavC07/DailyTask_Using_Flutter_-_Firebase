import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'theme_dialog.dart';

class SettingsMenu extends StatelessWidget {
  final VoidCallback onSyncTasks;
  final VoidCallback onLoadTasks;

  const SettingsMenu({
    super.key,
    required this.onSyncTasks,
    required this.onLoadTasks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: theme.colorScheme.onSurface,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) async {
            switch (value) {
              case 'sync':
                onSyncTasks();
                break;
              case 'logout':
                await authService.signOut();
                break;
              case 'offline':
                await authService.setOfflineMode(
                  !await authService.isOfflineMode(),
                );
                onLoadTasks();
                break;
              case 'theme':
                ThemeDialog.show(context);
                break;
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'sync',
                  child: Row(
                    children: [
                      Icon(
                        authService.isAuthenticated
                            ? Icons.sync_rounded
                            : Icons.login_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        authService.isAuthenticated ? 'Sync Tasks' : 'Sign In',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined),
                      SizedBox(width: 12),
                      Text('Theme Settings'),
                    ],
                  ),
                ),
                if (authService.isAuthenticated)
                  PopupMenuItem(
                    value: 'offline',
                    child: FutureBuilder<bool>(
                      future: authService.isOfflineMode(),
                      builder: (context, snapshot) {
                        final isOffline = snapshot.data ?? false;
                        return Row(
                          children: [
                            Icon(
                              isOffline
                                  ? Icons.cloud_off_rounded
                                  : Icons.cloud_rounded,
                              color:
                                  isOffline
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(isOffline ? 'Go Online' : 'Go Offline'),
                          ],
                        );
                      },
                    ),
                  ),
                if (authService.isAuthenticated)
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign Out',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
              ],
        );
      },
    );
  }
}
