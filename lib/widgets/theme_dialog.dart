import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class ThemeDialog extends StatelessWidget {
  const ThemeDialog({super.key});

  static void show(BuildContext context) {
    showDialog(context: context, builder: (context) => const ThemeDialog());
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeService themeService,
    ThemeMode mode,
    String title,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = themeService.themeMode == mode;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Card(
        elevation: isSelected ? 3 : 0,
        color:
            isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                isSelected
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : theme.colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color:
                  isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color:
                  isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                isSelected
                    ? Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                      key: const ValueKey('selected'),
                    )
                    : Icon(
                      Icons.radio_button_unchecked,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.6,
                      ),
                      key: const ValueKey('unselected'),
                    ),
          ),
          onTap: () {
            themeService.setThemeMode(mode);
            Navigator.of(context).pop();

            // Show confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Theme changed to $title'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Theme Settings'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose your preferred theme for the app',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeOption(
                context,
                themeService,
                ThemeMode.light,
                'Light Mode',
                Icons.light_mode_rounded,
                'Always use light theme',
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                context,
                themeService,
                ThemeMode.dark,
                'Dark Mode',
                Icons.dark_mode_rounded,
                'Always use dark theme',
              ),
              const SizedBox(height: 8),
              _buildThemeOption(
                context,
                themeService,
                ThemeMode.system,
                'System Mode',
                Icons.auto_mode_rounded,
                'Follow system theme',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
