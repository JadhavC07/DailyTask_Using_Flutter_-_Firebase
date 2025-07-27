import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.task_alt,
                  size: 60,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // Welcome Text
              Text(
                'Daily Tasks',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Organize your daily tasks efficiently',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Feature highlights
              _buildFeatureItem(
                Icons.cloud_sync,
                'Cloud Sync',
                'Access your tasks from anywhere',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.offline_bolt,
                'Offline First',
                'Works without internet connection',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.notifications_active,
                'Smart Reminders',
                'Never miss a task with daily notifications',
              ),
              const SizedBox(height: 48),

              // Sign in buttons
              Consumer<AuthService>(
                builder: (context, authService, child) {
                  return Column(
                    children: [
                      // Google Sign In
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await authService.signInWithGoogle();
                          },
                          icon: Image.asset(
                            'assets/images/google_logo.png', // Add Google logo
                            height: 20,
                            width: 20,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.login, size: 20);
                            },
                          ),
                          label: const Text('Continue with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Continue as Guest
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await authService.continueAsGuest();
                          },
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Continue as Guest'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Privacy note
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
