// main.dart — KOVA App Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/screens/splash_screen.dart';
import 'package:kova/screens/parent_profile_screen.dart';
import 'package:kova/screens/child_profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for mobile
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar to blend with background
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const KovaApp());
}

class KovaApp extends StatelessWidget {
  const KovaApp({super.key});

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

      // -- Routes --
      initialRoute: KovaRoutes.splash,
      routes: {
        KovaRoutes.splash: (context) => const SplashScreen(),
        KovaRoutes.parentProfile: (context) => const ParentProfileScreen(),
        KovaRoutes.childProfile: (context) => const ChildProfileScreen(),
      },
    );
  }
}
