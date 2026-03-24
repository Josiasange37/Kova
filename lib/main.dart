// main.dart — KOVA App Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/page_transitions.dart';
import 'package:kova/screens/splash_screen.dart';
import 'package:kova/screens/parent_profile_screen.dart';
import 'package:kova/screens/child_profile_screen.dart';
import 'package:kova/screens/whatsapp_connect_screen.dart';
import 'package:kova/screens/monitored_apps_screen.dart';
import 'package:kova/screens/welcome_screen.dart';
import 'package:kova/screens/accessibility_setup_screen.dart';
import 'package:kova/screens/success_screen.dart';
import 'package:kova/screens/dashboard_screen.dart';
import 'package:kova/screens/alert_history_screen.dart';
import 'package:kova/screens/alert_detail_screen.dart';
import 'package:kova/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for mobile
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar to blend with background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const KovaApp());
}

class KovaApp extends StatelessWidget {
  const KovaApp({super.key});

  // ── Route → Screen mapping ──
  static final _routeBuilders = <String, Widget Function()>{
    KovaRoutes.welcome: () => const WelcomeScreen(),
    KovaRoutes.parentProfile: () => const ParentProfileScreen(),
    KovaRoutes.childProfile: () => const ChildProfileScreen(),
    KovaRoutes.whatsappConnect: () => const WhatsappConnectScreen(),
    KovaRoutes.monitoredApps: () => const MonitoredAppsScreen(),
    KovaRoutes.accessibilitySetup: () => const AccessibilitySetupScreen(),
    KovaRoutes.success: () => const SuccessScreen(),
    KovaRoutes.dashboard: () => const DashboardScreen(),
    KovaRoutes.alertHistory: () => const AlertHistoryScreen(),
    KovaRoutes.alertDetail: () => const AlertDetailScreen(),
    KovaRoutes.settings: () => const SettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOVA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: KovaColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KovaColors.primary,
          primary: KovaColors.primary,
          secondary: KovaColors.accent,
          surface: KovaColors.cardWhite,
          error: KovaColors.danger,
        ),
        textTheme: GoogleFonts.nunitoTextTheme().apply(
          bodyColor: KovaColors.textPrimary,
          displayColor: KovaColors.textPrimary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: KovaColors.primary,
            foregroundColor: KovaColors.textOnDark,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KovaRadius.button),
            ),
            textStyle: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),

      // -- Routes with custom transitions --
      initialRoute: KovaRoutes.splash,
      onGenerateRoute: (settings) {
        // Splash uses default (no transition needed)
        if (settings.name == KovaRoutes.splash) {
          return MaterialPageRoute(
            builder: (_) => const SplashScreen(),
            settings: settings,
          );
        }

        // All other routes use smooth slide-up + fade
        final builder = _routeBuilders[settings.name];
        if (builder != null) {
          return KovaPageRoute(page: builder());
        }

        // Fallback — unknown route goes to splash
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      },
    );
  }
}
