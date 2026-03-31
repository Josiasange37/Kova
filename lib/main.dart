// main.dart — KOVA App Entry Point
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kova/core/app_mode.dart';
import 'package:kova/core/constants.dart';
import 'package:kova/core/router.dart';
import 'package:kova/shared/services/local_storage.dart';
import 'package:kova/shared/services/notification_service.dart';
import 'package:kova/local_backend/database/database_service.dart';
import 'package:kova/child/services/detection_orchestrator.dart';

// App state
import 'package:kova/providers/app_state.dart';

// Parent services
import 'package:kova/parent/services/dashboard_data_service.dart';
import 'package:kova/parent/services/alert_history_service.dart';
import 'package:kova/parent/services/app_control_service.dart';
import 'package:kova/parent/services/child_profile_service.dart';
import 'package:kova/parent/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database factory for desktop platforms
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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
  await NotificationService.init();

  // Get app mode
  final appMode = await AppModeManager.getMode();

  // Start detection services ONLY if in child mode
  if (appMode == AppMode.child) {
    await DetectionOrchestrator.instance.start();
  }

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
    return MultiProvider(
      providers: [
        // Central app state
        ChangeNotifierProvider(create: (_) => AppState()),
        // Parent services
        ChangeNotifierProvider(create: (_) => DashboardDataService()),
        ChangeNotifierProvider(create: (_) => AlertHistoryService()),
        ChangeNotifierProvider(create: (_) => AppControlService()),
        ChangeNotifierProvider(create: (_) => ChildProfileService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
      ],
      child: Builder(
        builder: (context) {
          // Listen to settings for language changes
          final settings = context.watch<SettingsService>();
          
          return MaterialApp.router(
            title: 'KOVA',
            debugShowCheckedModeBanner: false,
            // Localization
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), // English
              Locale('fr'), // French
            ],
            locale: Locale(settings.language),
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
        },
      ),
    );
  }
}
