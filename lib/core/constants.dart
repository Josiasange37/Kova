// core/constants.dart — KOVA Design System Constants
import 'package:flutter/material.dart';

/// KOVA Design System Colors
class KovaColors {
  KovaColors._();

  /// Primary deep navy
  static const Color primary = Color(0xFF1B2B6B);

  /// Accent orange for waiting/warning states
  static const Color accent = Color(0xFFF5A623);

  /// Success green
  static const Color success = Color(0xFF2ECC71);

  /// Warm off-white background
  static const Color background = Color(0xFFF5F0E8);

  /// Card white
  static const Color cardWhite = Color(0xFFFFFFFF);

  /// Error / danger red
  static const Color danger = Color(0xFFE74C3C);

  /// Text primary (dark)
  static const Color textPrimary = Color(0xFF1B2B6B);

  /// Text secondary (muted)
  static const Color textSecondary = Color(0xFF7F8C9B);

  /// Text on dark backgrounds
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Divider / border color
  static const Color divider = Color(0xFFE8E2D9);
}

/// KOVA Design System Radius
class KovaRadius {
  KovaRadius._();

  /// Card border radius
  static const double card = 12.0;

  /// Button border radius
  static const double button = 8.0;

  /// Pill badge border radius
  static const double pill = 24.0;
}

/// KOVA Design System Spacing
class KovaSpacing {
  KovaSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

/// KOVA Asset Paths
class KovaAssets {
  KovaAssets._();

  static const String logoSvg = 'assets/svg/kova_logo.svg';
}

/// KOVA Route Names
class KovaRoutes {
  KovaRoutes._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String parentProfile = '/parent-profile';
  static const String childProfile = '/child-profile';
  static const String whatsappConnect = '/whatsapp-connect';
  static const String monitoredApps = '/monitored-apps';
  static const String accessibilitySetup = '/accessibility-setup';
  static const String success = '/success';
  static const String dashboard = '/dashboard';
  static const String alertHistory = '/alert-history';
  static const String alertDetail = '/alert-detail';
  static const String settings = '/settings';
}
