import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/services/crashlytics_service.dart';

class CrashTestWidget extends StatelessWidget {
  const CrashTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 Crashlytics Testing (Debug Only)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use these buttons to test Crashlytics integration:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await CrashlyticsService.log(
                        'Test log message from debug widget',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test log sent to Crashlytics'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('Test Log'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await CrashlyticsService.recordError(
                        exception: Exception('Test non-fatal error'),
                        reason: 'Testing Crashlytics error reporting',
                        fatal: false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Test non-fatal error sent to Crashlytics',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.warning, size: 16),
                  label: const Text('Test Error'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await CrashlyticsService.setCustomKey(
                        'test_key',
                        'test_value_${DateTime.now().millisecondsSinceEpoch}',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test custom key set in Crashlytics'),
                          backgroundColor: Colors.purple,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.key, size: 16),
                  label: const Text('Test Custom Key'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('⚠️ Test Crash'),
                          content: const Text(
                            'This will cause the app to crash for testing purposes. '
                            'The crash will be reported to Crashlytics.\n\n'
                            'Are you sure you want to proceed?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                // Add a small delay so the dialog closes first
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    CrashlyticsService.testCrash();
                                  },
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Crash App'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: const Text('Test Crash'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<bool>(
              future: CrashlyticsService.isCrashlyticsCollectionEnabled(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    'Crashlytics Collection: ${snapshot.data! ? 'Enabled' : 'Disabled'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: snapshot.data! ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }
                return const Text(
                  'Checking Crashlytics status...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
