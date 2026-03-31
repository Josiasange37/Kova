// core/router.dart — GoRouter setup for mode-based navigation
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'package:kova/core/app_mode.dart';

// ══════════════════════════════════════════
// ── SHARED SCREENS ──
// ══════════════════════════════════════════
import 'package:kova/shared/screens/pin_entry_screen.dart';

// ══════════════════════════════════════════
// ── PARENT SCREENS ──
// ══════════════════════════════════════════
import 'package:kova/parent/screens/splash_screen.dart' as parent_splash;
import 'package:kova/parent/screens/role_selection_screen.dart';
import 'package:kova/parent/screens/welcome_screen.dart' as parent_welcome;
import 'package:kova/parent/screens/parent_profile_screen.dart';
import 'package:kova/parent/screens/child_profile_screen.dart';
import 'package:kova/parent/screens/monitored_apps_screen.dart' as parent_apps;
import 'package:kova/parent/screens/whatsapp_connect_screen.dart';
import 'package:kova/parent/screens/success_screen.dart';
import 'package:kova/parent/screens/accessibility_setup_screen.dart'
    as parent_accessibility;
import 'package:kova/parent/screens/dashboard_screen.dart' as parent_dashboard;
import 'package:kova/parent/screens/alert_history_screen.dart';
import 'package:kova/parent/screens/alert_detail_screen.dart';
import 'package:kova/parent/screens/app_control_screen.dart';
import 'package:kova/parent/screens/settings_screen.dart';
import 'package:kova/parent/screens/pin_modification_screen.dart';

// ══════════════════════════════════════════
// ── CHILD SCREENS ──
// ══════════════════════════════════════════
import 'package:kova/child/screens/welcome_screen.dart' as child_welcome;
import 'package:kova/child/screens/whatsapp_connection_screen.dart';
import 'package:kova/child/screens/monitored_apps_screen.dart' as child_apps;
import 'package:kova/child/screens/parent_connection_screen.dart';
import 'package:kova/child/screens/accessibility_setup_screen.dart'
    as child_accessibility;
import 'package:kova/child/screens/dashboard_screen.dart' as child_dashboard;

/// Route path constants for go_router navigation
class AppRoutes {
  AppRoutes._();

  // ── Shared Routes ──
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String pinEntry = '/pin-entry';

  // ── Parent Flow Routes ──
  static const String parentWelcome = '/parent/welcome';
  static const String parentProfile = '/parent/profile';
  static const String childProfile = '/parent/child-profile';
  static const String parentMonitoredApps = '/parent/monitored-apps';
  static const String parentConnectChild = '/parent/connect-child';
  static const String parentSuccess = '/parent/success';
  static const String parentAccessibility = '/parent/accessibility';
  static const String parentDashboard = '/parent/dashboard';
  static const String alertHistory = '/parent/alert-history';
  static const String alertDetail = '/parent/alert-detail';
  static const String appControl = '/parent/app-control';
  static const String settings = '/parent/settings';
  static const String pinModification = '/parent/settings/pin-modification';

  // ── Child Flow Routes ──
  static const String childWelcome = '/child/welcome';
  static const String childWhatsappConnect = '/child/whatsapp-connect';
  static const String childMonitoredApps = '/child/monitored-apps';
  static const String childParentConnection = '/child/parent-connection';
  static const String childAccessibility = '/child/accessibility';
  static const String childDashboard = '/child/dashboard';
}

/// Build the router based on app mode
GoRouter buildRouter(AppMode initialMode) {
  return GoRouter(
    initialLocation: _getInitialRoute(initialMode),
    routes: [
      // ══════════════════════════════════════════
      // ── SHARED SCREENS (both modes) ──
      // ══════════════════════════════════════════

      // Splash Screen (uses parent splash which handles routing)
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const parent_splash.SplashScreen(),
      ),

      // Role Selection (Parent or Child choice)
      GoRoute(
        path: AppRoutes.roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      // PIN Entry for unlocking
      GoRoute(
        path: AppRoutes.pinEntry,
        builder: (context, state) =>
            PinEntryScreen(reason: state.extra as String? ?? 'unlock'),
      ),

      // ══════════════════════════════════════════
      // ── PARENT MODE ROUTES ──
      // ══════════════════════════════════════════

      // Parent Welcome Screen
      GoRoute(
        path: AppRoutes.parentWelcome,
        builder: (context, state) => const parent_welcome.WelcomeScreen(),
      ),

      // Parent Profile Screen (includes PIN creation)
      GoRoute(
        path: AppRoutes.parentProfile,
        builder: (context, state) => const ParentProfileScreen(),
      ),

      // Child Profile Screen (parent enters child info)
      GoRoute(
        path: AppRoutes.childProfile,
        builder: (context, state) => const ChildProfileScreen(),
      ),

      // Parent Monitored Apps Screen
      GoRoute(
        path: AppRoutes.parentMonitoredApps,
        builder: (context, state) => const parent_apps.MonitoredAppsScreen(),
      ),

      // Parent Connect Child Screen (QR/pairing code)
      GoRoute(
        path: AppRoutes.parentConnectChild,
        builder: (context, state) => const WhatsappConnectScreen(),
      ),

      // Parent Success Screen (setup complete)
      GoRoute(
        path: AppRoutes.parentSuccess,
        builder: (context, state) => const SuccessScreen(),
      ),

      // Parent Accessibility Setup Screen
      GoRoute(
        path: AppRoutes.parentAccessibility,
        builder: (context, state) =>
            const parent_accessibility.AccessibilitySetupScreen(),
      ),

      // Parent Dashboard (main screen after setup)
      GoRoute(
        path: AppRoutes.parentDashboard,
        builder: (context, state) => const parent_dashboard.DashboardScreen(),
      ),

      // Alert History Screen
      GoRoute(
        path: AppRoutes.alertHistory,
        builder: (context, state) => const AlertHistoryScreen(),
      ),

      // Alert Detail Screen
      GoRoute(
        path: AppRoutes.alertDetail,
        builder: (context, state) => const AlertDetailScreen(),
      ),

      // App Control Screen
      GoRoute(
        path: AppRoutes.appControl,
        builder: (context, state) => const AppControlScreen(),
      ),

      // Settings Screen
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // PIN Modification Screen
      GoRoute(
        path: AppRoutes.pinModification,
        builder: (context, state) => const PinModificationScreen(),
      ),

      // ══════════════════════════════════════════
      // ── CHILD MODE ROUTES ──
      // ══════════════════════════════════════════

      // Child Welcome Screen (same design as parent welcome)
      GoRoute(
        path: AppRoutes.childWelcome,
        builder: (context, state) => const child_welcome.WelcomeScreen(),
      ),

      // Child WhatsApp Connection Screen (Baileys pairing)
      GoRoute(
        path: AppRoutes.childWhatsappConnect,
        builder: (context, state) => const WhatsappConnectionScreen(),
      ),

      // Child Monitored Apps Screen
      GoRoute(
        path: AppRoutes.childMonitoredApps,
        builder: (context, state) => const child_apps.MonitoredAppsScreen(),
      ),

      // Child Parent Connection Screen (pair with parent)
      GoRoute(
        path: AppRoutes.childParentConnection,
        builder: (context, state) => const ParentConnectionScreen(),
      ),

      // Child Accessibility Setup Screen
      GoRoute(
        path: AppRoutes.childAccessibility,
        builder: (context, state) =>
            const child_accessibility.AccessibilitySetupScreen(),
      ),

      // Child Dashboard Screen
      GoRoute(
        path: AppRoutes.childDashboard,
        builder: (context, state) => const child_dashboard.DashboardScreen(),
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Route not found: ${state.uri}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.splash),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Determine the initial route based on app mode
String _getInitialRoute(AppMode mode) {
  return switch (mode) {
    AppMode.notConfigured => AppRoutes.splash,
    AppMode.parent => AppRoutes.parentDashboard,
    AppMode.child => AppRoutes.childDashboard,
  };
}
