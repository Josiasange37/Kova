import 'package:flutter/material.dart';
import '../theme/kova_theme.dart';
import 'final_active_screen.dart';

class AccessibilitySuccessScreen extends StatelessWidget {
  const AccessibilitySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large Animated Checkmark
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: KovaTheme.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 80,
                  color: KovaTheme.success,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Accessibility Enabled",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 24,
                  color: KovaTheme.textMain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "KOVA is now active and monitoring your social activities.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: KovaTheme.textSecondary),
              ),
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FinalActiveScreen(),
                    ),
                  );
                },
                child: const Text("Ok, got it"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
