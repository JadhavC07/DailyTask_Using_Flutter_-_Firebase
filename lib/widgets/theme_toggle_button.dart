import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  Widget _buildThemeToggleIcon(ThemeService themeService) {
    switch (themeService.themeMode) {
      case ThemeMode.light:
        return const Icon(Icons.light_mode_rounded);
      case ThemeMode.dark:
        return const Icon(Icons.dark_mode_rounded);
      case ThemeMode.system:
        return const Icon(Icons.auto_mode_rounded);
    }
  }

  String _getThemeLabel(ThemeService themeService) {
    switch (themeService.themeMode) {
      case ThemeMode.light:
        return 'Switch to Dark Mode';
      case ThemeMode.dark:
        return 'Switch to System Mode';
      case ThemeMode.system:
        return 'Switch to Light Mode';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return IconButton(
          onPressed: () => themeService.toggleTheme(),
          icon: _buildThemeToggleIcon(themeService),
          tooltip: _getThemeLabel(themeService),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer.withOpacity(
              0.1,
            ),
            foregroundColor: theme.colorScheme.primary,
          ),
        );
      },
    );
  }
}
