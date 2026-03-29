// core/router.dart — GoRouter setup for mode-based navigation
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'package:kova/core/app_mode.dart';

// Import all screens
// Shared screens (available to both modes)
import 'package:kova/shared/screens/splash_screen.dart';
import 'package:kova/shared/screens/mode_select_screen.dart';
import 'package:kova/shared/screens/pin_create_screen.dart';
import 'package:kova/shared/screens/pin_entry_screen.dart';

// Parent screens
import 'package:kova/parent/screens/parent_home_screen.dart';

// Child screens (placeholders for now)
// import 'package:kova/child/screens/setup/child_pairing_screen.dart';

/// Build the router based on app mode
GoRouter buildRouter(AppMode initialMode) {
  return GoRouter(
    initialLocation: _getInitialRoute(initialMode),
    routes: [
      // ══════════════════════════════════════════
      // ── SHARED SCREENS (both modes) ──
      // ══════════════════════════════════════════
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/select-mode',
        builder: (context, state) => const ModeSelectScreen(),
      ),

      GoRoute(
        path: '/pin-create',
        builder: (context, state) => const PinCreateScreen(),
      ),

      GoRoute(
        path: '/pin-entry',
        builder: (context, state) =>
            PinEntryScreen(reason: state.extra as String? ?? 'unlock'),
      ),

      // ══════════════════════════════════════════
      // ── PARENT MODE ROUTES ──
      // ══════════════════════════════════════════
      GoRoute(
        path: '/parent/home',
        builder: (context, state) => const ParentHomeScreen(),
      ),

      // ══════════════════════════════════════════
      // ── CHILD MODE ROUTES ──
      // ══════════════════════════════════════════
      GoRoute(
        path: '/child/protected',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Child Protected Mode (placeholder)')),
        ),
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Route not found: ${state.uri}')),
      );
    },
  );
}

/// Determine the initial route based on app mode
String _getInitialRoute(AppMode mode) {
  return switch (mode) {
    AppMode.notConfigured => '/select-mode',
    AppMode.parent => '/parent/home', // TODO: implement
    AppMode.child => '/child/protected', // TODO: implement
  };
}
