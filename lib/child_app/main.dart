import 'package:flutter/material.dart';
import 'theme/kova_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const KovaApp());
}

class KovaApp extends StatelessWidget {
  const KovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOVA Child',
      debugShowCheckedModeBanner: false,
      theme: KovaTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
