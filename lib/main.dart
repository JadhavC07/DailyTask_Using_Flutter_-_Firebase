import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/sync_service.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up notification listeners before initialization
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: NotificationService.onActionReceivedMethod,
    onNotificationCreatedMethod:
        NotificationService.onNotificationCreatedMethod,
    onNotificationDisplayedMethod:
        NotificationService.onNotificationDisplayedMethod,
  );

  try {
    // Initialize Firebase with options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');

    // Initialize local database first
    await DatabaseService.database;
    debugPrint('✅ Local database initialized');

    // Initialize Notifications
    await NotificationService.initialize();
    debugPrint('✅ Notifications initialized');

    // Initialize existing tasks notifications
    await _initializeTaskNotifications();
    debugPrint('✅ Task notifications initialized');

    // Initialize sync service
    SyncService.initialize();
    debugPrint('✅ Sync service initialized');

    debugPrint('✅ App initialization completed');
  } catch (e) {
    debugPrint('❌ Initialization error: $e');
  }

  runApp(const MyApp());
}

Future<void> _initializeTaskNotifications() async {
  try {
    // Get all tasks with due times
    final tasks = await DatabaseService.getLocalTasks();
    final tasksWithDueTimes =
        tasks.where((task) => task.hasDueTime && !task.isCompleted).toList();

    debugPrint(
      '🔔 Initializing notifications for ${tasksWithDueTimes.length} tasks',
    );

    // Schedule notifications for each task
    for (final task in tasksWithDueTimes) {
      try {
        await NotificationService.scheduleAllTaskNotifications(task);
      } catch (e) {
        debugPrint('❌ Error scheduling notifications: $e');
      }
    }

    // Check for immediate notifications
    await NotificationService.checkAndSendImmediateNotifications();

    // Setup daily reminder
    await NotificationService.scheduleDailyReminder();
  } catch (e) {
    debugPrint('❌ Error initializing task notifications: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Daily Tasks',
            // Use the theme service for light and dark themes
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            themeMode: themeService.themeMode,
            // Updated navigation logic
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// Add Splash Screen for proper initialization
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Add a small delay for splash effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate to AuthWrapper
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.white),
            SizedBox(height: 24),
            Text(
              'Daily Tasks',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
