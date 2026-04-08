import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/pdf_providers.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BookApp(),
    ),
  );
}

class BookApp extends StatelessWidget {
  const BookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF89B4FA),
          secondary: Color(0xFFA6E3A1),
          surface: Color(0xFF1E1E2E),
          onSurface: Color(0xFFCDD6F4),
        ),
        scaffoldBackgroundColor: const Color(0xFF181825),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
