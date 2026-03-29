// shared/screens/splash_screen.dart — Initial loading screen
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/shared/services/local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Initialize local storage
    await LocalStorage.init();

    // Wait a moment for splash animation
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // Check app mode
    final mode = await AppModeManager.getMode();

    // Navigate based on mode
    if (mounted) {
      switch (mode) {
        case AppMode.notConfigured:
          context.go('/select-mode');
          break;
        case AppMode.parent:
          context.go('/parent/home');
          break;
        case AppMode.child:
          context.go('/child/protected');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2B6B), Color(0xFF0F1B47)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // KOVA Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    'KOVA',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading...',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
