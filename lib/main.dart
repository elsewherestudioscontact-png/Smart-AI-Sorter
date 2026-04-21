import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/settings_screen.dart';
import 'services/secure_storage_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  final storage = SecureStorageService();
  final hasApiKey = await storage.hasApiKey();

  runApp(
    ProviderScope(
      child: SmartAISorterApp(initialRoute: hasApiKey ? '/home' : '/setup'),
    ),
  );
}

class SmartAISorterApp extends StatelessWidget {
  final String initialRoute;

  const SmartAISorterApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart AI Sorter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const SplashScreen(),
        '/setup': (context) => const SetupScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
