// main.dart — KOVA App Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:kova/core/app_mode.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/local_backend/database/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize services
  await LocalStorage.init();
  await DatabaseService().database;

  // Get app mode
  final appMode = await AppModeManager.getMode();

  runApp(KovaApp(initialMode: appMode));
}

class KovaApp extends StatefulWidget {
  final AppMode initialMode;

  const KovaApp({super.key, required this.initialMode});

  @override
  State<KovaApp> createState() => _KovaAppState();
}

class _KovaAppState extends State<KovaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(widget.initialMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
      routerConfig: _router,
    );
  }
}
