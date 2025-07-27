import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return FutureBuilder<bool>(
          future: authService.isOfflineMode(),
          builder: (context, snapshot) {
            final isOfflineMode = snapshot.data ?? false;

            // Show home screen if authenticated OR in offline mode
            if (authService.isAuthenticated || isOfflineMode) {
              return const HomeScreen();
            }

            // Show login screen for first-time users
            return const LoginScreen();
          },
        );
      },
    );
  }
}
